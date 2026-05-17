---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "docs", "infrastructure", "adr-0029"]
dependencies: []
adrs: ["ADR-0029"]
wave: 1
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-architecture
---

# Feature: Author `infrastructure/cloudflare-domain-transfer.md` walkthrough

## Summary
Author the generic GoDaddy → Cloudflare domain-transfer walkthrough that the per-domain migration packets (P4, P5) consume. Portal-first; covers the full transfer flow once, so per-domain packets only need to verify the result rather than re-document the steps.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0029 §If Accepted requires `infrastructure/cloudflare-domain-transfer.md`. ADR-0029 §Implementation sketches the per-domain transfer steps (unlock, auth code, snapshot, initiate, approve, wait, verify, lock, update vendor inventory) but defers the full walkthrough to this packet.

The walkthrough is **per-domain-agnostic** — it describes the procedure once. The migration packets (P4 for `honeydrunkstudios.com`, P5a for `tatteddev.com`, P5b for `honeyhub.app`) reference this walkthrough rather than duplicating the steps. Subdomain wiring under an already-Cloudflare-authoritative apex (e.g., `notify.honeydrunkstudios.com` for ADR-0027, `status.honeydrunkstudios.com` for a future status page) is **not** a domain transfer and does not consume this walkthrough — those records are created in the consuming Node's own ADR rollout.

The walkthrough captures the parts of the transfer flow that are common to every domain: GoDaddy-side unlock and auth-code retrieval, DNSSEC and 2FA pre-transfer checks, the pre-transfer DNS record snapshot for rollback, the Cloudflare-side transfer initiation with pre-populated zone records, the multi-day wait for transfer completion, the post-cutover smoke window (T+0 to T+48h) covering mail-loop probes and third-party verification record reachability, post-transfer verification, and the Registrar-level transfer-lock posture. Domain-specific verification (the actual hostname's TLS + ingress + downstream Node behavior) lives in the per-domain migration packets.

## Proposed Implementation

### New file: `infrastructure/cloudflare-domain-transfer.md`

Match the structural template used by the existing portal walkthroughs. Sections:

1. **Goal** — produce a Cloudflare-registered, Cloudflare-authoritative domain with the source GoDaddy registration replaced cleanly and a verified zone of DNS records carrying the same content (or improved content per the per-domain packet's intent).

2. **Applies to** — every per-domain migration packet (P4, P5, and any future migration). Does not apply to subdomain creation under an already-Cloudflare-authoritative apex (no transfer involved).

3. **Pre-transfer prerequisites**
   - Cloudflare account stood up per [`cloudflare-account-provisioning.md`](cloudflare-account-provisioning.md).
   - Hardware-key 2FA active on the Cloudflare account.
   - **GoDaddy 2FA second factor is currently working.** Sign in to `account.godaddy.com` and complete the 2FA challenge to confirm the second factor is reachable. If 2FA recovery codes were saved at enrollment, locate and verify accessibility (1Password / equivalent). If lost or unreachable, regenerate before starting any transfer — losing access to GoDaddy 2FA mid-transfer is a recovery scenario that costs days.
   - GoDaddy account access (the user's credentials; the agent does not have these).
   - Domain is at least 60 days old since registration or last transfer (ICANN policy — domains under 60 days cannot transfer between registrars). Verify in the GoDaddy domain detail page before starting.
   - Domain is not in any restricted state (delete pending, dispute, etc.). Verify in GoDaddy.
   - **DNSSEC is OFF at GoDaddy for this domain pre-transfer.** Verify under DNS settings → DNSSEC. If ON, disable and wait for propagation (typically 24-48 hours) before initiating the transfer. Transferring with DNSSEC enabled risks resolution failures during the registrar handoff because the new authority (Cloudflare) cannot serve signed responses with the old chain of trust.

4. **Step-by-step — GoDaddy-side preparation (human-driven)**
   - Sign in to `account.godaddy.com`.
   - Navigate to **My Products → Domains → {domain}**.
   - On the domain detail page, take a full snapshot of the DNS records:
     - GoDaddy → DNS → Manage Zones → {domain}.
     - Use the **Export** function to download the zone as a standard zone file (BIND format). Save with filename `{domain}-godaddy-export-{YYYY-MM-DD}.zone` and store outside the Cloudflare account (1Password vault item or studio-local backup).
     - Manually screenshot the GoDaddy DNS table as a secondary record — formatting differences between GoDaddy's export and Cloudflare's import occasionally lose niche record types or comments.
   - Disable **Domain Privacy** if enabled. Cloudflare cannot accept transfer of domains with privacy proxies that mask the registrant. Privacy is re-enabled at Cloudflare post-transfer.
   - **Unlock the domain** — Settings → Domain Lock → Off. Confirm the lock-status indicator shows Unlocked.
   - **Request the transfer authorization code** — Settings → Transfer → Send Authorization Code to Email. The code arrives at the registrant email on file. Save the code outside any Grid-managed system (1Password) — this is a transfer-grade credential.

5. **Step-by-step — Cloudflare-side transfer initiation**
   - Sign in to `dash.cloudflare.com`.
   - Navigate to **Domain Registration → Transfer Domains**.
   - Enter the apex domain. Cloudflare confirms transfer eligibility and presents the at-cost registry fee (compare against the GoDaddy renewal price the studio was paying — the savings figure goes in the per-domain packet's Acceptance Criteria as documentation).
   - Pre-populate the zone before approving the transfer:
     - Cloudflare offers an automated DNS scan that polls the current authoritative nameservers (GoDaddy's, at this point) and pre-imports observed records.
     - Compare the pre-imported list against the BIND export from step 4. Add any missing records manually. Cross-check niche record types (TXT verification records, MX, SPF, DKIM, DMARC, CAA, SRV) — automated scan occasionally misses uncommon types.
     - Add `purpose=...` comments to each record per the lean record-comment scheme in [`cloudflare-account-provisioning.md`](cloudflare-account-provisioning.md). Do not include `initiative`, `created-by`, dates, or owner names.
     - For each record, decide proxied (orange-cloud) vs. DNS-only (grey-cloud) per the per-domain packet's intent. ADR-0029 D3 sets defaults: proxied for public marketing surfaces, DNS-only for API-shaped surfaces backed by Container Apps, DNS-only for email records.
   - Enter the transfer authorization code from step 4.
   - Submit the transfer.

6. **Step-by-step — During transfer (5–7 day window)**
   - Cloudflare emails the registrant for transfer-approval confirmation. Approve.
   - GoDaddy may also email a confirmation request; some flows allow expediting by approving on both sides immediately.
   - DNS continues serving from GoDaddy's nameservers during the transfer window. Cloudflare does not become authoritative until the registrar transfer completes AND the user updates the nameserver records.
   - Monitor: `whois {domain}` shows the registrar transition; `dig NS {domain}` shows the authoritative nameserver transition (separate event).

7. **Step-by-step — Post-transfer verification**
   - Cloudflare emails completion. Verify in **Domain Registration → Manage** that the domain is listed under Cloudflare.
   - Update nameservers — Cloudflare provides two nameserver hostnames (e.g., `noah.ns.cloudflare.com`, `tegan.ns.cloudflare.com`; specific names assigned per-account at zone creation). The transfer flow typically configures nameservers automatically; verify in the Cloudflare zone overview.
   - Run DNS resolution checks from outside the studio's network:
     - `dig +trace {domain}` to verify resolution path terminates at Cloudflare nameservers.
     - `dig {domain} A` to verify the A record content matches the imported zone.
     - For each subdomain in the imported zone, verify `dig {subdomain}.{domain}` returns the expected record.
   - Verify TLS — `curl -vI https://{domain}` to confirm certificate chain and any expected proxy headers (Cloudflare adds `cf-ray` when proxied).
   - **Apply Registrar-level transfer lock** — Cloudflare Domain Registration → {domain} → Configuration → Registrar Lock → On. Confirm lock indicator shows On.
   - Re-enable any privacy proxy if the per-domain packet calls for it (Cloudflare's WHOIS privacy is on by default for at-cost transfers; verify in zone settings).

8. **Step-by-step — Post-cutover smoke (T+0 to T+48h)**

   The verification commands in step 7 confirm the registrar transfer and authoritative DNS handoff completed cleanly. They do not catch slow-burn breakage — a third-party verification record that quietly drops out of "verified" because the new authority's response shape differs slightly from the old, an SPF chain that resolves but loses DKIM alignment, a DMARC `rua=` mailbox that no longer receives reports. The post-cutover smoke window catches these.

   **Mail-loop probe.** If the domain has any mailbox routing (MX records present in the BIND export):
   - Send a test message **to** a known address on the domain (e.g., the studio's own inbox, or a personal address aliased onto the domain). Record send time.
   - Send a test message **from** that address out to a known external mailbox (e.g., a personal Gmail / Outlook address that is NOT on this domain).
   - Inspect the received message's full headers in both directions. Verify `Authentication-Results` shows `dkim=pass`, `spf=pass`, and `dmarc=pass` (or `dmarc=none` if no DMARC was configured pre-transfer; do not regress it to `fail`). If any of the three is `fail`, stop and triage before proceeding with downstream packets.

   **Third-party verification TXT records.** The BIND export from step 4 lists every TXT record that was authoritative pre-transfer. Many of these are third-party domain-ownership proofs (Google Workspace site verification, Microsoft 365 / Azure tenant verification, Stripe domain verification, Vercel `_vercel`, Resend `_resend`, etc.). For each TXT-verification record present in the export:
   - Identify the issuing service (the host name pattern `_{service}` or the value's prefix is usually the giveaway).
   - Sign in to that service's portal.
   - Verify the domain still shows as "verified" / "active" in the service's domain-management surface. Do this for all third-party services in turn — services occasionally re-poll asynchronously and a record that resolves correctly via `dig` can still be marked "needs reverification" in the service portal for several hours.
   - If a service shows the domain as un-verified or pending, do not panic — check the record value at Cloudflare against the value the service expects. A `dig` mismatch indicates a transcription error during pre-import and warrants a record edit at Cloudflare. A `dig` match with a portal "needs reverification" usually clears within 24 hours; click the service's "re-verify" / "check now" button if available.

   **DMARC `rua=` reachability.** If DMARC was configured pre-transfer and `rua=` (aggregate report URI) was set:
   - Verify the mailbox at the `rua=` address is reachable. DMARC reports take 24-48 hours to start arriving from major providers (Google, Microsoft, Yahoo). Watch the inbox at T+24h and T+48h.
   - If no reports have arrived by T+72h and reports were arriving pre-transfer, treat as a regression — the most common cause is a typo in the `rua=` address during pre-import or a record-type confusion (DMARC must be a TXT under `_dmarc.{domain}`, not a TXT at the apex).

   **Smoke completion criteria.** The 48-hour smoke is "passed" when: mail-loop probe shows pass-pass-pass, every third-party verification record from the BIND export is confirmed verified in its respective service portal, and (if applicable) DMARC reports have started arriving at `rua=` again. Record the smoke result in the per-domain migration packet's PR body.

9. **Step-by-step — Cleanup at GoDaddy**
   - Sign in to GoDaddy. Verify the domain has moved out — it appears in the domain list with status "Transferred Out" for a retention period before disappearing entirely.
   - Cancel any GoDaddy add-ons that were attached to the domain (privacy, premium DNS, etc.) — they did not transfer with the domain and continue billing if not cancelled.
   - If GoDaddy was the auto-renew payment surface for the domain, confirm the auto-renew is now off on the GoDaddy side. Cloudflare's auto-renew is on by default; verify in Cloudflare per-domain settings.

10. **Verification checklist**
    - `whois {domain}` shows Cloudflare as registrar.
    - `dig NS {domain}` returns Cloudflare nameservers only.
    - All records from the BIND export are present in the Cloudflare zone with `purpose=...` comments.
    - TLS resolves correctly via the documented serving path (Cloudflare proxy + downstream origin, or DNS-only + downstream origin).
    - Registrar Lock is On at Cloudflare.
    - GoDaddy auto-renew is Off and any GoDaddy add-ons are cancelled.
    - Post-cutover smoke (step 8) is passed: mail-loop, third-party verification records, DMARC `rua=` reachability.
    - The per-domain packet's domain-specific verification steps pass (TLS chain to expected origin, downstream Node ingress responds, etc.).

11. **Rollback**
    - During the transfer window (before transfer completes): cancel the transfer in Cloudflare. The domain stays at GoDaddy. No DNS impact.
    - After the transfer completes: initiate a transfer-back to GoDaddy. Same procedure in reverse, with a 60-day post-transfer wait per ICANN policy. Re-import the BIND export at GoDaddy if their DNS surface was changed during the brief Cloudflare-authoritative window.
    - **DNS-level rollback (without registrar transfer back):** if the registrar transfer is fine but a specific record change broke a downstream Node, restore that record from the BIND export inside the Cloudflare zone. No registrar transfer required.
    - **Smoke-window rollback for a third-party verification regression:** if step 8's third-party verification check shows a service marking the domain as un-verified, the rollback is per-record at Cloudflare — re-paste the value from the BIND export for that one record. No registrar action required.

12. **Cross references**
    - [ADR-0029](../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md)
    - [`cloudflare-account-provisioning.md`](cloudflare-account-provisioning.md) — Cloudflare-side prerequisites.
    - Per-domain migration packets (each references this walkthrough rather than duplicating the steps).

### Edits to `infrastructure/README.md`

Add the second bullet to the new "Cloudflare platform" section (P2 adds the section header and the first bullet):

```
- [Cloudflare domain transfer](cloudflare-domain-transfer.md) — Generic per-domain transfer walkthrough (GoDaddy → Cloudflare). Per-domain migration packets reference this.
```

If P2 has not merged when this packet's PR is opened, add the section header itself plus both bullets — the two packets are coordinated and either ordering is acceptable.

### `CHANGELOG.md`
Append an entry to the existing in-progress `## [Unreleased]` section under `### Added`:
- "`infrastructure/cloudflare-domain-transfer.md` walkthrough — generic GoDaddy → Cloudflare per-domain transfer flow with rollback."

## Affected Files
- `infrastructure/cloudflare-domain-transfer.md` (new)
- `infrastructure/README.md` (new bullet under Cloudflare platform; section header if P2 has not landed yet)
- `CHANGELOG.md`

## Boundary Check
- [x] Architecture-repo doc-only change. No catalog graph changes.
- [x] No code in any Node touched. No invariant text changes.
- [x] No secret values in the walkthrough — convention and example only (invariant 8). No real auth codes, account IDs, or registrar identifiers.

## Acceptance Criteria
- [ ] `infrastructure/cloudflare-domain-transfer.md` exists with all sections enumerated above (Goal, Applies to, Pre-transfer prerequisites, GoDaddy-side preparation, Cloudflare-side transfer initiation, During transfer, Post-transfer verification, Post-cutover smoke (T+0 to T+48h), Cleanup at GoDaddy, Verification checklist, Rollback, Cross references).
- [ ] Pre-transfer prerequisites section explicitly names: hardware-key 2FA on the Cloudflare account, working GoDaddy 2FA second factor (signed-in confirmation + recovery codes accessible), 60-day ICANN minimum, no restricted state, and **DNSSEC OFF at GoDaddy with 24-48 hour propagation if it was previously ON**.
- [ ] GoDaddy-side preparation section explicitly names: BIND zone export + manual screenshot, Domain Privacy disable, domain unlock, transfer authorization code request and out-of-Grid storage.
- [ ] Cloudflare-side transfer initiation section names the pre-import scan, manual cross-check against the BIND export for niche record types, the lean `purpose=` comment scheme per [`cloudflare-account-provisioning.md`](cloudflare-account-provisioning.md), and the proxied vs. DNS-only decision per ADR-0029 D3 defaults.
- [ ] Post-transfer verification section names the Registrar Lock On step explicitly and includes `whois`, `dig +trace`, `dig NS`, and `curl -vI` verification commands.
- [ ] **Post-cutover smoke section names the mail-loop probe (DKIM + SPF + DMARC headers checked), third-party verification record enumeration (each TXT-verification record from the BIND export checked in its issuing service portal), and DMARC `rua=` reachability check at T+24h / T+48h / T+72h.**
- [ ] Cleanup at GoDaddy section names auto-renew off and add-on cancellation explicitly.
- [ ] Rollback section names both during-transfer cancellation and post-transfer transfer-back, plus DNS-level rollback for a single bad record without registrar transfer, plus smoke-window per-record rollback for a third-party verification regression.
- [ ] No secret values in the walkthrough — convention only (invariant 8). No real auth codes, account IDs, customer IDs.
- [ ] `infrastructure/README.md` Cloudflare platform section has the domain-transfer bullet present.
- [ ] `CHANGELOG.md` `## [Unreleased]` section has the added-entry described above.
- [ ] PR description references this packet (invariant 32).

## Human Prerequisites
None at the packet level — the walkthrough is authored against Cloudflare's and GoDaddy's public documentation. Per-domain execution of the walkthrough (the actual transfer for a specific domain) carries human prerequisites — those are scoped to P4 / P5, not this packet.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The walkthrough is documentation; no actual transfer auth codes, account IDs, or credentials in the doc. Conventions and example commands only.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0029 §If Accepted:** Mandates this walkthrough exists. The packet is the direct fulfillment.

**ADR-0029 §Implementation (per-domain transfer steps):** Names the step sequence (unlock, auth code, snapshot, initiate, approve, wait, verify, lock, update vendor inventory). The walkthrough is the full version of that sketch.

**ADR-0029 D3 (default proxy posture):** "Public marketing surfaces — proxied (orange-cloud). API-shaped surfaces backed by Container Apps — DNS-only (grey-cloud) at v1 unless a concrete reason to proxy emerges. Email-related records (MX, SPF, DKIM, DMARC) — DNS-only by definition." The Cloudflare-side initiation section references these defaults; the per-domain packet decides the actual proxied/DNS-only setting per record.

**ADR-0029 §Negative Consequences (Registrar Lock mitigation):** "Registrar-level transfer lock is enabled" as part of the migration. The post-transfer verification section enforces this.

## Dependencies
None. P2 and P3 are foundation walkthroughs; either can land first. The dispatch plan recommends parallel execution.

## Labels
`feature`, `tier-2`, `docs`, `infrastructure`, `adr-0029`

## Agent Handoff

**Objective:** Author the generic GoDaddy → Cloudflare per-domain transfer walkthrough as a portal-first runbook with explicit rollback paths.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Stand up the per-domain transfer documentation surface that P4 and P5 reference rather than duplicate.
- Feature: ADR-0029 Cloudflare DNS & Edge Platform Rollout, foundation wave.
- ADR: ADR-0029 (Proposed).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. No real auth codes, account IDs, or credentials in the walkthrough — conventions, example commands, and placeholder strings only.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.
- **Portal-first.** Per ADR-0029 D2 and the Grid's documented convention. CLI is appendix material at most. The verification commands (`whois`, `dig`, `curl`) are diagnostic-CLI, which is acceptable — they are not provisioning-CLI.
- **Per-domain-agnostic.** The walkthrough does not name `honeydrunkstudios.com` or any other specific domain. P4 and P5 reference the walkthrough for the procedure and supply the domain-specific specifics.
- **Default proxy posture per ADR-0029 D3.** The walkthrough records the defaults; the per-domain packet records the per-record decision.

**Key Files:**
- `infrastructure/cloudflare-domain-transfer.md` (new — the walkthrough)
- `infrastructure/README.md` (Cloudflare platform section bullet)
- `CHANGELOG.md`

**Reference Walkthroughs (style/structure to mirror):**
- `infrastructure/walkthroughs/key-vault-creation.md`
- `infrastructure/walkthroughs/oidc-federated-credentials.md`
- `infrastructure/walkthroughs/container-app-creation.md`

**Contracts:** None changed. Doc-only packet.
