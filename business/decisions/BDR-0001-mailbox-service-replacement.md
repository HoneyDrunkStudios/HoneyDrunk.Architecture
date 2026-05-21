# BDR-0001: Mailbox Service Replacement — Leaving iPostal1 for VPM

**Status:** Accepted
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Target execution complete by:** 2026-09-30 (switch + Sunbiz amendment + IRS/Chase updates before October)
**Affects:** Entity (FL LLC principal address), recurring vendor list

---

## Context

HoneyDrunk Studios LLC uses iPostal1 as its FL business mailbox **and** as the principal office address on file with Sunbiz. Annual cost ~$400.

The service has been failing the basic job: the local franchise location is **not scanning incoming mail**. Because iPostal1 (and Anytime Mailbox) operate as a franchise/aggregator model — they license the storefront to a local CMRA who does the actual scanning — service quality is location-dependent and currently bad.

This BDR decides what we switch to and lays out the switch plan (which includes a Sunbiz amendment to change the LLC's principal address). Target: complete switch before October 2026.

## Constraints

1. **Must be a Florida street address.** It's the LLC's principal office on Sunbiz; Sunbiz requires a real FL street address.
2. **Reliable scanning is the #1 requirement** — that's why we're leaving.
3. **Fully remote operation, no in-person visits ever.** Every mail action — view, forward, scan contents, shred — must be doable from an app/portal. The Studio principal will never travel to the physical location.
4. **Should reduce or hold cost** vs the current ~$400/yr if possible.
5. **Should support our actual mail patterns** — low volume, mostly state/tax/legal notices. No paper-check handling required (Chase business hasn't been mailing checks; confirmed in resolved inputs below).
6. **Switch is reversible but painful** — Sunbiz amendment, update Chase, update IRS/state tax accounts, update any vendors with our address on file.

> Note on constraint 3: every major provider advertises these features. The differentiator isn't *whether* they offer scan/forward/shred — it's whether the people receiving the physical mail are actually employed by the provider you're paying. Franchise/aggregator providers (iPostal1, Anytime Mailbox) license the storefront to a local CMRA; the features exist in the app, but the local operator decides whether to do the work. Corporate-operated providers (VPM, Earth Class Mail, Stable) employ the scanning staff directly. The current iPostal1 failure is a textbook symptom of the franchise model going wrong locally.

## Options

Two structural categories matter more than brand:

**Franchise/aggregator model** — iPostal1, Anytime Mailbox, PostScan Mail. Cheap, many FL cities, but mail handling is done by a local CMRA the company doesn't employ. Quality varies by location. *This is the model we're leaving.*

**Corporate-operated** — VirtualPostMail (VPM), Earth Class Mail / LegalZoom Mail, Stable, Traveling Mailbox. The company employs the people scanning. Fewer FL locations, generally higher price, but scanning SLAs are real.

### Candidate shortlist (FL street address, corporate-operated)

| Service | FL location(s) | Plan / monthly | Annual | Registered agent included | Notes |
|---|---|---|---|---|---|
| **VirtualPostMail (VPM)** | FL (verify city) | ~$20–$30 | ~$240–$360 | **Yes, free** with plan | Unlimited storage, searchable scans, corporate-operated, free RA bundled |
| **Northwest Registered Agent** | All FL cities (they have own offices) | $29 | $348 | **Yes, bundled** | Built around RA + mail; well-regarded for privacy |
| **Stable** | FL (Miami / others) | $49 ("Grow") | $588 | No (separate) | Polished tooling, accounting integrations |
| **Earth Class Mail** | FL | $29 entry | $348 | No (separate) | Long-established; LegalZoom-owned now |
| **Traveling Mailbox** | FL | $15 (Basic) / $25 (Standard) | $180–$300 | No | Worldwide forwarding; check deposit option |

### Out of scope (rejected categories)

- **Anytime Mailbox, PostScan Mail, staying with iPostal1** — same franchise model that's failing us now. Switching from iPostal1 to Anytime Mailbox at the same FL city is likely to land us with the same kind of local operator.
- **Personal/home address on Sunbiz** — kills the privacy reason for having a virtual mailbox in the first place.

## Resolved Inputs (2026-05-21)

1. **Mail volume / checks:** Low volume, no paper checks. Cheapest tier of any provider works; no need for check-deposit feature.
2. **Registered agent:** Studio principal is own RA. No RA bundling needed; "free RA" perks (VPM, Northwest) are not a tiebreaker.
3. **Sunbiz timing:** File standalone amendment now (~$25), don't wait for 2027 Annual Report. Goal is the new address on file with FL before October.
4. **FL city preference:** Tampa or Orlando. No strong tie to a specific city.

## Recommendation

**Switch to VirtualPostMail (VPM), Tampa location.**

Reasoning:

- **Fixes the actual problem.** VPM operates its own facilities and employs the people scanning — not a franchise/aggregator. That's the structural cause of iPostal1's failure for us; VPM doesn't have it.
- **Cost neutral or better.** ~$20–$30/mo = ~$240–$360/yr vs current $400/yr iPostal1.
- **Tampa confirmed available** (downtown near Water Street District; Brandon also available in Tampa metro). Orlando is not a VPM market.
- **Unlimited storage + searchable scan archive** — useful years out for legal/tax records.
- **Free RA bundled** — not needed today (principal is own RA), but there if we ever change our mind, with no migration friction.

Alternatives considered and not chosen:

- **Stable (Tampa)** — polished UX and accounting integrations, but $49/mo ($588/yr) is materially more expensive without giving us anything we need (no checks, no team scaling). Revisit if accounting workflow ever needs it.
- **Earth Class Mail / LegalZoom Mail** — $29/mo, comparable to VPM, but specific Tampa/Orlando city availability is unclear from public info and the LegalZoom acquisition adds vendor-direction risk. Skip unless VPM Tampa falls through.
- **Northwest Registered Agent** — strong RA-focused option, but we don't need the RA bundle and it's $29/mo flat with no advantage over VPM for our use.

## Decision

**Switch to VirtualPostMail (VPM), FL location (Tampa downtown or Brandon — pick at signup based on per-location pricing and address optics).** Confirmed 2026-05-21.

Rationale (one-line): VPM is corporate-operated, so the people scanning our mail are VPM employees — which structurally fixes the iPostal1 failure mode without paying Stable's premium. All four hard requirements satisfied (FL street address, reliable scanning, fully remote workflow, cost ≤ current).

## Consequences

Once decided, the switch involves:

1. **Open new account** with chosen provider; complete USPS Form 1583 (notarized — most providers handle this online via Notarize.com or similar).
2. **Mail forwarding** — set USPS forwarding from iPostal1 address to new address for safety net (12 months).
3. **Sunbiz amendment** — file Articles of Amendment to change principal office address ([sunbiz form](https://dos.fl.gov/SunbizEmail/SunbizChange/SunbizAddressChange) or bundle with next Annual Report).
4. **Update Chase business** — change address on file (in-branch or via secure message).
5. **Update IRS** — Form 8822-B (within 60 days of change).
6. **Update FL Department of Revenue** if registered for any sales/use tax.
7. **Update vendor address book** — anyone with our business address on file (insurance, payment processors, accountants, etc.).
8. **Cancel iPostal1** at the end of the current billed period.
9. **Update `business/context/entity.md`** with new address and change-log entry.

## Action Items

Sequenced — don't cancel iPostal1 or change Sunbiz until VPM is live and forwarding is in place.

- [ ] **Sign up with VPM** — pick Tampa downtown vs Brandon at checkout; record final address + plan + monthly cost in `business/context/entity.md`
- [ ] **Complete USPS Form 1583** — VPM handles via online notarization; needed before any mail can be processed
- [ ] **Verify VPM is active** by sending a test piece of mail; confirm scan-on-receipt works
- [ ] **Set USPS mail forwarding** from iPostal1 address → new VPM address (12-month safety net)
- [ ] **File Sunbiz Articles of Amendment** to change LLC principal office address (~$25, standalone filing — don't wait for next Annual Report)
- [ ] **File IRS Form 8822-B** within 60 days of the address change
- [ ] **Update Chase business banking** address on file (secure message or branch visit)
- [ ] **Update FL Department of Revenue** if registered for any sales/use tax
- [ ] **Update vendor address book** — insurance carriers, payment processors, accountant, any contracts on file
- [ ] **Cancel iPostal1** at the end of the current billed period (after mail forwarding has been verified working for ≥30 days)
- [ ] **Update `business/context/entity.md`** — new address, change-log entry, vendor table reflects VPM replacing iPostal1
- [ ] **Add change-log entry to this BDR** when execution is complete

---

## References

- [Sunbiz — Update Principal Office or Mailing Address](https://dos.fl.gov/SunbizEmail/SunbizChange/SunbizAddressChange)
- [Sunbiz — Articles of Amendment process](https://dos.fl.gov/sunbiz/manage-business/update-information/)
- [IRS Form 8822-B (Change of Address — Business)](https://www.irs.gov/forms-pubs/about-form-8822-b)
- [USPS Form 1583 (required for commercial mail receiving)](https://about.usps.com/forms/ps1583.pdf)
