# Handoff — Wave 5: Governance Close

**Wave:** 4 → 5 transition
**Initiative:** `adr-0049-pii-classification`
**ADR:** ADR-0049

## What landed in Wave 4

- **Core-sector live Nodes backfilled** (packet 07): `HoneyDrunk.Auth`, `HoneyDrunk.Vault`, `HoneyDrunk.Data` all carry `[Classification]` and `[PiiField]` markers on every persisted-record/contract/Audit-payload property. Solution-version bumps released to the package feed. `security` specialist reviewed each PR.
- **Ops-sector live Nodes backfilled** (packet 08): `HoneyDrunk.Notify`, `HoneyDrunk.Communications` (and possibly `HoneyDrunk.Pulse` if it persists tenant-attributable records) all carry markers. Notify's message-body fields carry `[PiiField(Pii)]` or `[PiiField(SensitivePii)]` per content-domain assessment. Solution-version bumps released. `security` specialist reviewed each PR.
- The `HoneyDrunk.Standards` analyzer rule from packet 03 fires **zero warnings** against the touched files post-backfill (per the completion signal in 07 and 08).

## What Wave 5 closes

Three parallel packets:

### Packet 09 — Catalog population (`HoneyDrunk.Architecture`)

Walk the post-backfill Grid surface and populate `catalogs/data-classification.json` per-Node entries (the schema from packet 01 has been empty since Wave 1). Also annotate `catalogs/contracts.json` interface entries with `classification` and `pii_categories` fields.

Per-Node entry shape (from ADR-0049 D9):
```json
"HoneyDrunk.Notify": {
  "highest_classification": "Restricted",
  "pii_categories": ["Pii"],
  "sensitive_pii": false,
  "contracts": [
    {
      "name": "INotificationSender.SendAsync",
      "request_class": "Restricted",
      "fields": ["RecipientEmail:Pii", "MessageBody:Pii", "Tenant:Pseudonymous"]
    },
    {
      "name": "AuditEntry(NotifySent)",
      "request_class": "Confidential",
      "fields": ["RecipientPrincipalId:Pseudonymous"]
    }
  ],
  "stores": [
    { "name": "DeliveryAttempts", "class": "Restricted", "retention_class": "tenant-active" }
  ]
}
```

Cover the 12 Live-signal Nodes plus Pulse and Audit (Seed but marker-bearing). AI-sector Seed Nodes (Memory, Knowledge, etc.) are deferred to their own standup packets per ADR-0049 D10 Phase 6 — leave them out.

### Packet 10 — Analyzer flip + hive-sync reconciliation (`HoneyDrunk.Standards` + `HoneyDrunk.Architecture`)

Two sibling PRs:

**Standards PR** — flip the analyzer rule severity from `Warning` to `Error`. Unmarked fields on persisted-records/audit-payloads now fail the build at the tier-1 gate. Bump the Standards solution one minor version per invariant 27.

**Architecture PR** — wire `hive-sync` to reconcile `catalogs/data-classification.json` against source-code markers nightly per ADR-0014's reconciliation pattern. Drift findings emit via the standard board-item path per invariant 38.

**30-day window check.** ADR-0049 D10 Phase 1 commits a 30-day warning grace from packet 03's merge. The executor confirms 30 days have elapsed before flipping. If less, the agent flags this and **waits** — flipping early surprises in-flight backfill branches.

### Packet 11 — Agent file updates (`HoneyDrunk.Architecture`)

Three coordinated edits in one Architecture PR:

1. **`.claude/agents/security.md`** — append a new "ADR-0049 Data Classification Rubric" section. Inline the four-tier taxonomy, PII sub-taxonomy, retention pointers, attribute discipline, redaction expectations, erasure policy. Self-contained — the agent has no ADR access at execution time.
2. **`.claude/agents/review.md`** — amend the D3 category 9 (Security) checklist with new bullets for classification completeness, PII marker correctness, Restricted-boundary regression, SensitivePii-in-audit rejection, and cross-region movement.
3. **`.claude/agents/database.md`** — new specialist agent file authored from scratch. Scope: schema migrations on PII-bearing stores, index design vs erasure, retention configuration, AuditEntry table append-only-by-interface property, backup region. Manual invocation per ADR-0046 D1 at v1.

**Invariant 33 (review/scope agent context-loading coupling) check.** The `review.md` edit is a rule-list amendment — symmetry with `scope.md` preserved by construction. If the executor finds themselves adding a new required-reading file to `review.md`, the same file must be added to `scope.md` in the same PR.

**Architecture agents hardlinked.** After merge, re-sync the hardlinks per the documented procedure (`~/.claude/agents/`). Requires a Claude Code restart afterwards.

## Wave 6 runs separately

Packet 12 (DPA/TIA/DPF artifacts) is **`Actor=Human`** with `human-only` label; the agent-PR scaffolding can land any time after packet 00 merged (independent of Wave 4/5). The legal-substance completion is operator-only, paced separately.

## Closure check

After Wave 5 packets 09, 10, 11 land:
- [ ] Catalog populated with all Live-signal Nodes; hive-sync reconciles drift nightly.
- [ ] Analyzer rule at `Error` severity — unmarked fields fail CI Grid-wide.
- [ ] `security` specialist has the ADR-0049 D1–D6 rubric inline.
- [ ] `review` agent's D3 category 9 covers classification completeness.
- [ ] `database` specialist promoted to v1 roster with a published rubric.
- [ ] Invariant 47 amended; invariants 58/59/60 live.
- [ ] Pulse and Audit redactors operate against the marker surface; PII-scrubbing canary green.

Sibling **ADR-0050 (Tenant Lifecycle)** can now decompose into actionable packets — its D6-erasure-mechanics scope was blocked on this ADR's D6 principle being Accepted.

The Studio's commercial trajectory for Notify Cloud GA (ADR-0027) and the consumer-app PDR-driven packet generation (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities) now have the canonical classification rubric they need. The deferred Phase 6 consumer-app onboarding-store work proceeds in each PDR's own standup track.

Wave 6 packet 12's commercial/legal artifacts close ADR-0036 D7's deferred DPA work and ship the v1 TIA + DPF runbook — operator-paced, but architecturally enabled.
