---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0038", "wave-3"]
dependencies: ["packet:00", "packet:02", "packet:09"]
adrs: ["ADR-0038", "ADR-0029"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-sender-identity
node: honeydrunk-architecture
---

# Author the Cloudflare sender-identity DNS walkthrough and publish SPF/DKIM/DMARC/MTA-STS records

## Summary
Author `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` — a Cloudflare-portal UI walkthrough for the full sender-identity DNS record set per ADR-0038 D1/D2 — and execute it: publish SPF, DKIM, and DMARC records for the `mail.` and `notify.` sending subdomains, the apex DMARC record, and the MTA-STS / TLS-RPT records, all in the Cloudflare zone for `honeydrunkstudios.com`. This is `Actor=Human` — DNS record creation is portal work, and the developer prefers UI walkthroughs over CLI.

## Context
ADR-0038 D1 splits sending into reputation-isolated subdomains: `mail.honeydrunkstudios.com` (Studio transactional), `notify.honeydrunkstudios.com` (Notify Cloud platform sends). D2 mandates the full record set on every sending subdomain: SPF, DKIM, DMARC, plus MTA-STS and TLS-RPT at `p=enforce` for `mail.` and `notify.`. ADR-0038 D2 also states: "All records are managed in the Cloudflare zone (ADR-0029 portal-managed at v1)."

**Coordination with ADR-0029.** ADR-0029 commits Cloudflare as registrar and authoritative DNS, **portal-managed at v1, IaC deferred** (D2). ADR-0029's migration order moves the `honeydrunkstudios.com` apex to Cloudflare authoritative DNS first (migration step 1). ADR-0029 D3 explicitly names "Email-related records (MX, SPF, DKIM, DMARC) — DNS-only by definition" — these records are never proxied (grey-cloud). This packet's records therefore land in the Cloudflare zone ADR-0029 establishes; this packet is the email-record consumer of ADR-0029's DNS authority. **Hard real-world precondition: `honeydrunkstudios.com` must already be on Cloudflare authoritative DNS** before these records can be published authoritatively. If the ADR-0029 apex cutover has not happened, this packet is blocked on it (a real-world gate, recorded in Human Prerequisites, not a packet dependency since ADR-0029 has its own initiative).

This packet depends on packet 02 because the SPF record declares the **chosen ESP's** sending IPs and the DKIM selectors are namespaced per the chosen ESP — the walkthrough cannot be written concretely until the ESP is picked. It also depends on **packet 09** (hard): the DKIM **public keys** / selector records come from the ESP account packet 09 provisions. Packet 03 and packet 09 are both in **Wave 3** — packet 09 runs first within the wave, issues the DKIM selectors, and packet 03 then publishes the full record set including DKIM in a single pass. (A prior revision placed packet 03 in Wave 2, which made its DKIM acceptance criterion unsatisfiable within its own wave; moving it to Wave 3 alongside packet 09 resolves that wave inversion.)

This packet authors a walkthrough doc **and** executes it. The doc lives in `infrastructure/walkthroughs/` (sibling to `key-vault-creation.md`, `app-configuration-provisioning.md`, etc.). No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` (new) — the portal UI walkthrough.
- `catalogs/grid-health.json` — update `sender_reputation_status` for `mail.` and `notify.` from `not-provisioned` to `dns-published` once the records are live (the `dmarc_policy` starts at `none` per the D2 staged path).
- The Cloudflare zone for `honeydrunkstudios.com` — the actual DNS records (not a repo artifact).

## Proposed Work (human-executed, Cloudflare dashboard)
Author the walkthrough to cover, and then execute, the following — all records DNS-only (grey-cloud) per ADR-0029 D3:

1. **SPF** for `mail.` and `notify.` — a TXT record `v=spf1 include:<chosen-ESP-spf-domain> ~all` on each subdomain. `~all` (softfail) during warmup; the walkthrough documents the transition to `-all` after ≥30 days clean sending (D2) as a follow-up edit, not a day-one record.
2. **DKIM** for `mail.` and `notify.` — the selector records the chosen ESP provides (typically CNAMEs pointing at the ESP's DKIM-key host, or TXT records with the 2048-bit RSA public key). Selectors namespaced per ESP, e.g. `s1._domainkey.notify`. This step consumes the DKIM selectors packet 09 issues; packet 09 runs first within Wave 3, so the DKIM records are published in the same pass as the rest of the set.
3. **DMARC** — a TXT record at `_dmarc.honeydrunkstudios.com` covering the subdomains. **Initial policy `p=none`** for the 14-day aggregate-report observation window per D2; the walkthrough documents the staged transition to `p=quarantine` (pct=100) after 14 days, then `p=reject` as steady state. `rua=` and `ruf=` point at the Studio-monitored reporting address / the DMARC aggregator endpoint configured in packet 04.
4. **MTA-STS** for `mail.` and `notify.` — the `_mta-sts` TXT record plus the policy file served at `https://mta-sts.<subdomain>/.well-known/mta-sts.txt`. ADR-0038 D2 sets `mode: enforce` from day one. The walkthrough notes the policy-file hosting requirement (a small static file — document where it is served from).
5. **TLS-RPT** for `mail.` and `notify.` — the `_smtp._tls` TXT record pointing reports at the Studio reporting address.
6. **Record comments** — per ADR-0029 D6's lean comment scheme, each record's Cloudflare comment field carries `purpose=` only (e.g. `purpose=notify-cloud-spf`), no initiative names, no owner.
7. After publication, **verify** with the standard tooling (the walkthrough documents using a DMARC/SPF/DKIM checker) and update `grid-health.json` `sender_reputation_status` to `dns-published`.

## Affected Files
- `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` (new)
- `catalogs/grid-health.json` — `sender_reputation_status` updates for `mail.` and `notify.`

## NuGet Dependencies
None. This packet has no .NET project — it is a Cloudflare-portal walkthrough plus a catalog update.

## Boundary Check
- [x] The walkthrough doc and the `grid-health.json` update live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and catalog metadata.
- [x] No code change in any repo.
- [x] DNS records land in the Cloudflare zone (a vendor surface, not a Node) — consistent with ADR-0029 placing all Grid DNS in Cloudflare.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` exists as a step-by-step Cloudflare-portal UI walkthrough covering SPF, DKIM, DMARC, MTA-STS, and TLS-RPT
- [ ] The walkthrough explicitly documents the DKIM-step ordering dependency on the ESP account (packet 09) and the apex-on-Cloudflare precondition (ADR-0029)
- [ ] The walkthrough documents the D2 staged transitions: SPF `~all` → `-all` (≥30 days) and DMARC `p=none` → `p=quarantine` → `p=reject` (14-day observation)
- [ ] SPF, DMARC, MTA-STS, and TLS-RPT records are published in the Cloudflare zone for the `mail.` and `notify.` subdomains and the apex DMARC record exists
- [ ] DKIM records are published using the selectors packet 09's ESP account provides (packet 09 runs first within Wave 3)
- [ ] All email records are DNS-only (grey-cloud) per ADR-0029 D3; record comments use the lean `purpose=` scheme per ADR-0029 D6
- [ ] DMARC starts at `p=none` (observation), not `p=quarantine` — the staged path is followed
- [ ] `catalogs/grid-health.json` `sender_reputation_status` for `mail.` and `notify.` is updated to `dns-published` after verification
- [ ] No DKIM private key, ESP API key, or any secret appears in the walkthrough or anywhere in the repo (invariant 8) — DKIM private keys live in Vault per packet 09

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] **`honeydrunkstudios.com` must be on Cloudflare authoritative DNS** — the ADR-0029 apex cutover (migration step 1) must have completed. If ADR-0029's apex migration packet has not run, this packet is blocked on it. See [`ADR-0029-cloudflare-dns-and-edge-platform.md`](../../../../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md).
- [ ] **The ESP account exists** (packet 09, which runs first in Wave 3) so the DKIM selectors and public keys are available before this packet's DKIM step.
- [ ] Cloudflare dashboard access for the `honeydrunkstudios.com` zone.
- [ ] A decision on where the MTA-STS policy file (`/.well-known/mta-sts.txt`) is hosted — a small static file requiring an HTTPS endpoint on `mta-sts.<subdomain>`.
- [ ] The reporting address for DMARC `rua`/`ruf` and TLS-RPT — configured in packet 04; if packet 04 has not run, use a placeholder and return.

## Referenced ADR Decisions
**ADR-0038 D1 — Sending-domain architecture: subdomains per send-type.** `mail.honeydrunkstudios.com` for Studio transactional mail; `notify.honeydrunkstudios.com` for Notify Cloud platform sends. The apex `honeydrunkstudios.com` is reserved for human correspondence and marketing — minimal sending volume. Splitting transactional from platform sends is reputation isolation.

**ADR-0038 D2 — Email authentication: full SPF + DKIM + DMARC at strict policy.** Every sending subdomain gets the full record set. SPF declares the ESP's sending IPs (`~all` during warmup, `-all` after ≥30 days clean sending). DKIM uses 2048-bit RSA keys, one per ESP-relationship, selectors namespaced per ESP (`s1._domainkey.notify`). DMARC is published on the apex covering subdomains: `p=quarantine` with `pct=100` after 14 days of `p=none` aggregate-report observation; steady state `p=reject`; `rua`/`ruf` route to a Studio-monitored inbox. MTA-STS and TLS-RPT are published at `p=enforce` for `mail.` and `notify.` from day one. All records are managed in the Cloudflare zone.

**ADR-0029 D2 — Cloudflare authoritative DNS, portal-managed at v1.** All DNS records for Grid domains are managed in the Cloudflare dashboard, not IaC. The apex `honeydrunkstudios.com` moves to Cloudflare authoritative DNS first (migration step 1).

**ADR-0029 D3 — Default proxy posture.** "Email-related records (MX, SPF, DKIM, DMARC) — DNS-only by definition." These records are never proxied (grey-cloud).

**ADR-0029 D6 — Lean record-comment scheme.** Cloudflare DNS record comments carry record purpose only (`purpose=studios-apex`), no initiative names or owners.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** DKIM **private** keys never enter the repo or the walkthrough. Only the DKIM *public* key / selector records are DNS-resident (public by definition). Private keys are held by the ESP and, where the Grid manages rotation, in Vault per packet 09 and ADR-0006.

- **Coordinate with ADR-0029, do not duplicate it.** This packet does not migrate the apex or transfer the domain — that is ADR-0029's initiative. This packet only adds email records to the zone ADR-0029 establishes. If the apex is not yet on Cloudflare, stop and flag.
- **DMARC starts at `p=none`.** The staged path is mandatory — do not publish `p=quarantine` on day one. 14 days of aggregate-report observation first, then `p=quarantine`, then `p=reject`. The walkthrough documents all three stages but day-one publication is `p=none`.
- **Portal-only, UI walkthrough.** No CLI, no Cloudflare API, no Terraform — ADR-0029 D2 and the developer's portal-over-CLI preference. The walkthrough is click-by-click.
- **DKIM after the ESP exists.** The DKIM record step consumes packet 09's ESP-issued selectors. Packet 09 runs first within Wave 3; the walkthrough sequences the DKIM step after it.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Author the Cloudflare sender-identity DNS walkthrough and publish the full SPF/DKIM/DMARC/MTA-STS/TLS-RPT record set for `mail.` and `notify.` plus the apex DMARC record.

**Target:** Tracked against `HoneyDrunk.Architecture`; the DNS work is human-executed in the Cloudflare dashboard. `Actor=Human` — `human-only` label set. The walkthrough doc lands in `infrastructure/walkthroughs/`.

**Context:**
- Goal: Establish the authenticated sending-identity DNS posture ADR-0038 D1/D2 mandate, in the Cloudflare zone ADR-0029 establishes.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D1 / D2 (primary), ADR-0029 D2 / D3 / D6 (Cloudflare DNS authority, DNS-only email records, lean comment scheme).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted before its DNS obligation is executed.
- `packet:02` — hard. The ESP must be picked before the SPF include-domain and DKIM selector namespace can be written concretely.
- `packet:09` — hard. The DKIM selector records come from the ESP account packet 09 provisions. Both packets are in Wave 3; packet 09 runs first.
- **ADR-0029 apex cutover** — hard real-world precondition (not a packet dependency — ADR-0029 has its own initiative). `honeydrunkstudios.com` must be on Cloudflare authoritative DNS. Enforced via the Human Prerequisites checklist.

**Constraints:**
- Coordinate with ADR-0029 — do not migrate the apex or transfer the domain here; only add email records.
- DMARC starts at `p=none` — staged path mandatory.
- Portal-only UI walkthrough — no CLI, no API, no IaC.
- No DKIM private keys or secrets in the repo (invariant 8).

**Key Files:**
- `infrastructure/walkthroughs/cloudflare-sender-identity-dns.md` (new)
- `catalogs/grid-health.json`

**Contracts:** None — DNS records, no code.
