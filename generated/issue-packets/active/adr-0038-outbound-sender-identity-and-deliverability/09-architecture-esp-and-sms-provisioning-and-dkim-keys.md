---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0038", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0038", "ADR-0006"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-architecture
---

# Provision the ESP account, generate DKIM keys, and register the Studio toll-free SMS number

## Summary
Author `infrastructure/walkthroughs/esp-and-sms-provisioning.md` and execute it: create the primary ESP account (the vendor picked in packet 02), generate the 2048-bit DKIM keys for `mail.` and `notify.`, and register + verify the Studio transactional toll-free SMS number with the SMS provider. `Actor=Human` — ESP/SMS provider account creation, KYC, and toll-free verification are console work the developer prefers as a UI walkthrough; no code artifact.

## Context
ADR-0038 D3 commits to a primary ESP + cold fallback; packet 02 records the vendor pick. This packet stands up the **primary** ESP account so the sending infrastructure actually exists. ADR-0038 D2 requires 2048-bit RSA DKIM keys, one per ESP-relationship, selectors namespaced per ESP — those keys are generated here (or by the ESP, depending on the vendor's DKIM-delegation flow). ADR-0038 D4 requires a single toll-free number for Studio transactional SMS, registered and verified through the SMS provider.

This packet is the human/portal foundation the DNS packet (03) and the Notify provider-backing depend on for *real* sending — but it is sequenced carefully:

- **Packet 03 (DNS)** publishes the DKIM selector records. Those records need the DKIM **public** key / selector host from the ESP account this packet creates. Packet 03's walkthrough explicitly handles "DKIM after the ESP exists" — so 03 and 09 can both be in Wave-adjacent flight, with 03's DKIM step completing after 09.
- **Packets 05–07 (Notify code)** use in-memory ESP fakes for tests (invariant 15) — they do **not** block on this packet. Real end-to-end sending against the ESP is a post-merge validation, not a code-merge gate.

**Secrets discipline.** The ESP API key, the SMS provider auth token, and the DKIM **private** keys are secrets. Per invariant 8 they never enter the repo. Per ADR-0029 D5 / ADR-0005 the convention is per-Node Vault storage (`<Vendor>--ApiKey`). However: `HoneyDrunk.Notify`'s Key Vault is the right home, and the actual seeding into Vault is operational work that pairs with the Notify deployment. This packet **provisions the accounts and records that they exist** (in `business/context/` / `infrastructure/`), notes the Vault secret names that will hold the keys, and seeds the keys into the Notify Key Vault if it exists — but the seeding step is gated on the Notify Key Vault being provisioned. If it is not, this packet records the keys' destination and flags the seeding as a follow-up. No key value is ever committed.

This packet authors a walkthrough doc **and** executes it. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/esp-and-sms-provisioning.md` (new) — the ESP + SMS provisioning UI walkthrough.
- `infrastructure/reference/vendor-inventory.md` — confirm the ESP and SMS provider rows (packet 02 added them) now reflect a live account.
- `catalogs/grid-health.json` — `sender_reputation_status` notes annotation once the ESP account and toll-free number exist; the `studio-toll-free-sms` identity may move toward `warmup` once the number is verified and warmup begins (coordinate with the actual warmup start).
- The ESP account, DKIM keys, and toll-free SMS registration (vendor surfaces, not repo artifacts). Optionally the `HoneyDrunk.Notify` Key Vault secret entries (if the vault exists).

## Proposed Work (human-executed, ESP + SMS provider consoles)
1. **Create the primary ESP account** — the vendor from packet 02 (default lean: Resend). Sign up under a Studio-controlled email; complete any business verification the ESP requires.
2. **Add and verify the sending domains** in the ESP — `mail.honeydrunkstudios.com` and `notify.honeydrunkstudios.com`. The ESP issues DKIM selectors for each.
3. **DKIM keys** — per ADR-0038 D2, 2048-bit RSA, one per ESP-relationship, selectors namespaced per ESP. Most ESPs generate the DKIM keypair themselves and give you the public-key DNS records to publish; the private key stays with the ESP. If the chosen ESP's flow has the Grid generate keys, generate 2048-bit RSA. Either way: record the **public** selector records — they are handed to packet 03 for DNS publication. The **private** key never enters the repo.
4. **Set up the ESP subaccount model** — confirm subaccount-per-tenant capability is enabled / available (ADR-0038 D3/D5 reputation-isolation mechanism). At v1 there are no tenants yet; this step confirms the capability exists.
5. **Register the Studio toll-free SMS number** with the SMS provider (packet 02 pick, default lean: Twilio). Complete toll-free verification (carrier verification of the number for transactional use). Note: toll-free verification has its own clock — record the expectation.
6. **Record secret destinations, seed if possible.** The ESP API key and SMS provider auth token go into the `HoneyDrunk.Notify` Key Vault under ADR-0005 naming (e.g. `<Esp>--ApiKey`, `<SmsProvider>--AuthToken`). If the Notify Key Vault exists, seed them via the Azure Portal; if not, record the destination secret names in the walkthrough and flag the seeding as a follow-up gated on the Notify vault. **No key value in the repo.**
7. **Record the accounts exist** — update `infrastructure/reference/vendor-inventory.md` (live ESP + SMS accounts), and add a note to `business/context/` if vendor/billing records live there. Annotate `grid-health.json` `sender_reputation_status` notes.
8. **Do NOT yet** start the warmup ramp — warmup is an operational ramp coordinated with the first real sends; this packet stops at "accounts exist, domains verified, DKIM keys available, toll-free number verified." The warmup start is recorded in `grid-health.json` when it actually begins.

## Affected Files
- `infrastructure/walkthroughs/esp-and-sms-provisioning.md` (new)
- `infrastructure/reference/vendor-inventory.md`
- `catalogs/grid-health.json` — notes annotation
- `business/context/` vendor/billing record, if that is where vendor records live.

## NuGet Dependencies
None. This packet has no .NET project — ESP/SMS console work plus a walkthrough doc.

## Boundary Check
- [x] The walkthrough doc and catalog/inventory updates live in `HoneyDrunk.Architecture`.
- [x] No code change in any repo. The ESP API key, when seeded, goes into the `HoneyDrunk.Notify` Key Vault — not the repo.
- [x] ESP/SMS accounts are vendor surfaces, not Nodes.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/esp-and-sms-provisioning.md` exists as a step-by-step UI walkthrough
- [ ] The primary ESP account exists, with `mail.` and `notify.` added as verified sending domains
- [ ] The ESP has issued DKIM selectors for `mail.` and `notify.`; the public-key selector records are recorded and handed to packet 03 for DNS publication
- [ ] ESP subaccount-per-tenant capability is confirmed available (the D3/D5 reputation-isolation mechanism)
- [ ] The Studio transactional toll-free SMS number is registered and toll-free verification is complete (or in progress with the timeline recorded)
- [ ] The ESP API key and SMS provider auth token are either seeded into the `HoneyDrunk.Notify` Key Vault (if it exists) under ADR-0005 naming, or their destination secret names are recorded with the seeding flagged as a follow-up
- [ ] No ESP API key, SMS auth token, or DKIM **private** key appears anywhere in the repo (invariant 8)
- [ ] `vendor-inventory.md` reflects the live ESP and SMS accounts; `grid-health.json` notes are annotated
- [ ] The warmup ramp is NOT started in this packet — it begins as a separate operational step

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] The ESP and SMS provider picks must be confirmed (packet 02's operator decision).
- [ ] A Studio-controlled email for the ESP and SMS provider accounts.
- [ ] Any business-verification details the ESP or SMS provider's KYC flow requests.
- [ ] For toll-free SMS verification: the business/use-case details carriers require for transactional toll-free verification.
- [ ] For Vault seeding: the `HoneyDrunk.Notify` Key Vault must exist. If it does not, the seeding is recorded as a follow-up — see the Notify deployment / Key Vault provisioning walkthrough ([`key-vault-creation.md`](../../../../infrastructure/walkthroughs/key-vault-creation.md)).

## Referenced ADR Decisions
**ADR-0038 D2 — DKIM.** 2048-bit RSA keys, one per ESP-relationship, rotated annually per ADR-0006 lifecycle, selectors namespaced per ESP (`s1._domainkey.notify`).

**ADR-0038 D3 — ESP: primary + cold fallback, subaccount-per-tenant.** This packet provisions the primary. Subaccount-per-tenant is the reputation-isolation mechanism (D5).

**ADR-0038 D4 — SMS: a single toll-free number for Studio transactional.** One toll-free number registered and verified through the SMS provider.

**ADR-0038 D7 — Warmup.** `notify.` and the toll-free number begin sending under an explicit warmup ramp. This packet does not start the ramp — it stands up the accounts; the ramp is a coordinated operational step.

**ADR-0006 — Secret rotation and lifecycle.** DKIM keys rotate annually; ESP API keys are Tier 2 third-party secrets (≤ 90-day rotation SLA). The keys, when seeded, follow the ADR-0006 rotation lifecycle.

**ADR-0005 / ADR-0029 D5 — secret naming.** Vendor API keys are stored in the consuming Node's per-Node Key Vault under the documented naming convention and accessed via `ISecretStore` (invariant 9).

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No ESP API key, SMS provider auth token, or DKIM **private** key may be committed to the repo. DKIM **public** keys / selector records are DNS-resident and public by definition — those are recorded and handed to packet 03. Private keys stay with the ESP / in Vault.

> **Invariant 9 — Vault is the only source of secrets.** The ESP API key and SMS auth token, once seeded, are read via `ISecretStore` from the `HoneyDrunk.Notify` Key Vault — never from env vars or config files.

- **Portal/console UI walkthrough.** No CLI per the developer's preference.
- **Cheapest viable tier.** ESP and SMS provider plans default to the lowest viable tier — the Grid sends trivial volume at v1 (ADR-0038 Context). Show the cost before committing.
- **Stop before warmup.** This packet stands up accounts; it does not start the warmup ramp.
- **Vault seeding is gated on the Notify Key Vault.** If the Notify vault does not exist, record the destination secret names and flag the seeding — do not invent a vault.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Author the ESP + SMS provisioning walkthrough and execute it — create the primary ESP account, verify the sending domains, obtain DKIM selectors, register the Studio toll-free SMS number.

**Target:** Tracked against `HoneyDrunk.Architecture`; the work is human-executed in ESP and SMS provider consoles. `Actor=Human` — `human-only` label set. The walkthrough doc lands in `infrastructure/walkthroughs/`.

**Context:**
- Goal: Stand up the primary ESP account and the Studio toll-free SMS number so real sending infrastructure exists; hand the DKIM selector records to packet 03.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D2 / D3 / D4 / D7 (primary), ADR-0006 (secret rotation lifecycle), ADR-0005 (Vault secret naming).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The ESP and SMS provider must be picked before their accounts can be created.

**Constraints:**
- No secrets in the repo — ESP API key, SMS token, DKIM private keys never committed (invariant 8); public DKIM selector records go to packet 03.
- Portal/console UI walkthrough, no CLI.
- Cheapest viable tier — trivial v1 volume.
- Stop before the warmup ramp.
- Vault seeding gated on the Notify Key Vault existing — flag if absent.

**Key Files:**
- `infrastructure/walkthroughs/esp-and-sms-provisioning.md` (new)
- `infrastructure/reference/vendor-inventory.md`
- `catalogs/grid-health.json`

**Contracts:** None — vendor account provisioning, no code.
