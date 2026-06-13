# Implementation Notes — ADR-0029 Cloudflare as Registrar, Authoritative DNS, and Edge Platform

**Initiative:** `adr-0029-cloudflare-dns-rollout`
**Authored:** 2026-06-07 by the implementing agent (Claude Code), per ADR-0008 § Implementation-Notes Packets.
**Implementing PR:** HoneyDrunk.Architecture — ADR-0029 acceptance + catalog closeout (this PR).
**Operational work:** operator-driven portal clicks at GoDaddy and Cloudflare on 2026-06-07; agent owned the bookkeeping and verification guidance.

> The packets (P1–P5b) were filed (issues #98–103) but never executed as written — the operator and agent ran the migration live and discovered the rollout's premise was largely already satisfied. This record captures the as-built. The original decision (ADR-0029) and the filed packets are **not** rewritten; this is the retrospective overlay.

## What shipped

All three Grid-owned domains moved to **Cloudflare Registrar** with Cloudflare authoritative DNS, and the GoDaddy registrar relationship was wound down (all GoDaddy auto-renewals cancelled). Final state:

| Domain | Registrar | Expires | Notes |
|---|---|---|---|
| `honeydrunkstudios.com` | Cloudflare | 2029-07-25 | DNS already on Cloudflare pre-ADR; registrar-only transfer |
| `tatteddev.com` | Cloudflare | 2027-09-20 | DNS already on Cloudflare pre-ADR; registrar-only transfer |
| `honeyhub.app` | Cloudflare | 2027-09-20 | Was parked at GoDaddy; onboarded as a Cloudflare zone first, then transferred |

## The headline delta: registrar-only, not a DNS migration

ADR-0029 and its packets were scoped as a full **registrar + DNS + edge** migration off GoDaddy — BIND zone export, scan-and-cross-check import into Cloudflare, proxied/DNS-only per-record decisions, nameserver flip, Vercel-mode branching, and a T+0→T+48h post-cutover smoke (mail-loop probe, third-party verification records, DMARC `rua=` reachability).

**None of that was needed.** A Cloudflare account already existed (`Oleg@honeydrunkstudios.com`) and was already authoritative DNS — proxied, serving real traffic — for `honeydrunkstudios.com` and `tatteddev.com`, set up earlier during the now-retired ADR-0044 Tunnel work (the account's audit log still showed a "Delete a Cloudflare Tunnel" entry). So **D2 (authoritative DNS) was already true** for two of three domains, and the work reduced to **D1 (registrar transfer)**. A registrar transfer of a domain already on Cloudflare DNS touches no records and causes no downtime — the entire post-cutover smoke contract (P3 §8) was moot because the zone never changed.

Consequence for the deliverables:

- **P2 `cloudflare-account-provisioning.md` — descoped.** The account pre-existed; there was nothing to provision. (2FA is still on TOTP, not a hardware key — see Follow-ups.)
- **P3 `cloudflare-domain-transfer.md` — descoped.** The generic walkthrough would have documented DNS-migration ceremony that did not occur. The genuinely reusable artifact — the registrar-transfer recipe and its gotchas — is captured below instead of as a portal walkthrough.
- **P1 vendor-inventory transitional annotation — skipped.** Nothing executed incrementally, so there was no multi-week window to keep honest. The acceptance PR writes the **end state** directly (GoDaddy row removed, Cloudflare row scoped to registrar + DNS + edge, lock-in row added).
- **P4/P5 migration packets — executed as registrar-only transfers**, not the multi-day DNS cutovers they described.

## As-built registrar-transfer recipe (the part worth keeping)

Per domain already on Cloudflare DNS:

1. **GoDaddy → domain → Registration Settings → Domain Lock → off.**
2. **GoDaddy → "Transfer to Another Registrar" → Continue.** This identity-verify flow is what **removes "Ownership Protection"** and yields the **authorization code**.
3. **Cloudflare → Domains → Transfers** → select the domain (it appears under "Ready for transfer" once unlocked) → paste the auth code → pay the at-cost fee (~$10.46/yr for `.com`, includes one year's renewal).
4. Optionally approve the outbound transfer at GoDaddy to skip the ~5-day ICANN window; otherwise it auto-completes.
5. After completion: **verify ICANN registrant-contact email** (Cloudflare flags each domain "Email Verification Required" — unverified contacts risk suspension in ~15 days), and **keep Cloudflare auto-renew on**.

For a domain **not yet on Cloudflare** (`honeyhub.app`, parked at GoDaddy): first **add it as a Cloudflare zone** (scan imports existing records), **change the nameservers at GoDaddy** to the assigned Cloudflare pair, wait for the zone to go **Active**, *then* it becomes eligible for the registrar transfer above.

### Gotcha — GoDaddy "Ownership Protection" reads as a transfer objection

The first `tatteddev.com` attempt was rejected by GoDaddy with *"Express written objection to the transfer from the Transfer Contact."* The cause was **GoDaddy "Ownership Protection"** (their anti-transfer security plan), **not** WHOIS/domain privacy. The privacy off-toggle errored repeatedly and only ever reached a "Limited" state — which turned out to be a red herring. Going through the **"Transfer to Another Registrar" → verify identity** flow is what removes Ownership Protection ("it may take several minutes to be removed"), after which the transfer accepts. Lesson: don't chase the privacy toggle; the transfer-out flow itself clears the real blocker.

## Email finding — `honeydrunkstudios.com` mail is independent of GoDaddy

While winding down GoDaddy billing, the operator considered cancelling everything. GoDaddy's billing surface listed several Microsoft 365 / "Websites + Marketing with Email" subscriptions, which initially looked like they might back the live `oleg@honeydrunkstudios.com` inbox. **Verified in the M365 admin center (Billing → Your products) that the HoneyDrunk Studios M365 Business Standard subscription is "Purchase channel: Commercial direct"** — bought straight from Microsoft on the operator's own billing profile, **not GoDaddy-resold.** So the email is fully independent of the registrar move; cancelling GoDaddy lines cannot affect it. The GoDaddy M365 lines (including a `skylytsolutions.com` Business Professional from a previous business and an unused/never-set-up M365 seat) are leftovers, safe to cancel. Recorded so a future "leave GoDaddy entirely" pass doesn't re-litigate it. (This is also why the original ADR/packet framing of `honeydrunkstudios.com` as a Vercel-hosted marketing site with a fragile mail surface to smoke-test never materialized as a risk.)

## Convention deviations

- **Walkthroughs not authored.** ADR-0029 §If Accepted listed `cloudflare-account-provisioning.md` and `cloudflare-domain-transfer.md` as obligations. Both were descoped (above); the "If Accepted" checklist is annotated `[~]` with the rationale rather than left unchecked. If a future domain registration/transfer wants a portal runbook, the recipe above is the seed.
- **End-state vendor-inventory edit, not the incremental P1→P4→P5 sequence** the dispatch plan specified. Justified because nothing landed incrementally, so there was no intermediate catalog state to keep honest.

## Follow-ups surfaced

- **Hardware-key 2FA on the Cloudflare account.** ADR-0029 §Negative Consequences makes hardware-key-backed 2FA mandatory; the account is currently on TOTP. Operator to enroll a hardware key (YubiKey or equivalent) + keep TOTP as backup. Tracked as a residual hardening item, not a blocker.
- **ICANN registrant-contact verification.** Operator to clear "Email Verification Required" on all three domains in the Cloudflare Registrations dashboard (suspension risk if left unverified ~15 days).
- **GoDaddy account closure (optional).** With all domains transferred and auto-renewals off, the GoDaddy account can be closed at the operator's discretion once the leftover M365/website subscriptions are dealt with. Out of scope for this initiative.
- **Registrar Lock per zone.** Confirm Cloudflare Registrar Lock is on for each domain (ADR-0029 §Negative Consequences mitigation).
