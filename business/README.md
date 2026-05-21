# Business

Studio-level operations: legal entity, banking, vendors, insurance, contracts. Anything that isn't Grid architecture (ADRs), product strategy (PDRs), or code, but that an AI agent or future-me needs to reason about a HoneyDrunk Studios business decision.

## Layout

- `context/` — current state of the business. Read these to understand entity, banking, vendors, and recurring obligations before making changes.
- `decisions/` — Business Decision Records (BDRs). One file per decision, dated, with status. Same shape as ADRs/PDRs but scoped to operations.

## What goes here

**Yes:**
- Vendor selection (mail/address, registered agent, accounting software, payroll, insurance carriers)
- Entity changes (address amendments, registered agent swaps, EIN, state filings)
- Banking and payment processing decisions
- Contracts the studio signs (service agreements, NDAs, licenses received/granted)
- Insurance policies (general liability, E&O, cyber)
- Tax structure decisions

**No:**
- Product positioning → use `pdrs/`
- Code/Grid architecture → use `adrs/`
- Personal finances unrelated to the LLC

## Conventions

- BDRs follow `BDR-NNNN-short-slug.md`
- Status values: Proposed · Accepted · Superseded · Rejected
- Context files are living documents — update in place when the underlying fact changes (e.g., new bank, new address) and note the change date.
