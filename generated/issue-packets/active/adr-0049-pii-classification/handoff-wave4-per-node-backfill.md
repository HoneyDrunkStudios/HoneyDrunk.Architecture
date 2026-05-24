# Handoff — Wave 4: Per-Node Backfill

**Wave:** 3 → 4 transition
**Initiative:** `adr-0049-pii-classification`
**ADR:** ADR-0049

## What landed in Waves 2–3

### Contracts (Wave 2)
- **`HoneyDrunk.Kernel.Abstractions`** at the new minor version, exposing `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory`. Namespace `HoneyDrunk.Kernel.Abstractions.DataClassification`.
- **`HoneyDrunk.Standards.Analyzers`** at the new minor version, with the unmarked-classification rule at **`Warning`** severity. Detection scope: records/classes in projects referencing `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions`.

### Redactors and canary (Wave 3)
- **`HoneyDrunk.Pulse`** Azure Monitor sink runs `PiiAwareLogRecordProcessor` and `PiiAwareSpanProcessor` (registered by default in `AddAzureMonitorTelemetry`). The `IErrorReporter` Pulse backing walks `Exception.Data` and `ErrorContext.Tags`. `[PiiField(Pii)]` → marker replacement; `[PiiField(SensitivePii)]` → `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` → pass-through. `evals.sensitive=true` span carve-out preserved. StackTrace never redacted.
- **`HoneyDrunk.Audit`** append path runs `AuditPayloadRedactor`. `[PiiField(Pii)]` → pseudonymous `AuditPiiToken` via injected `IAuditTokenizer`. `[PiiField(SensitivePii)]` → **rejection** (typed failure result; no entry persisted; operational telemetry signal carries field name + classification, never the value). `[PiiField(Pseudonymous)]` → pass-through. `IAuditTokenizer` is the seam; v1 ships an `InMemoryAuditTokenizer` stub; production wiring against the per-Node identity store is ADR-0050's scope.
- **`HoneyDrunk.Pulse`** carries the cross-boundary PII-scrubbing canary in its canary suite. Asserts every redaction outcome plus the Evals carve-out, the StackTrace-pass-through rule, the regex fallback for unstructured exception messages, and the audit append-only-by-interface property. A canary failure blocks the package release per ADR-0034.

## What Wave 4 does

Backfill `[Classification]` and `[PiiField]` markers across the Live-signal Nodes that touch persisted records, contract types, and `AuditEntry`-payload types.

**Two coordinator packets, parallel:**

### Packet 07 — Core-sector backfill (`HoneyDrunk.Vault` → `HoneyDrunk.Data` → `HoneyDrunk.Auth`)

Three sequential PRs in three repos. Order matters: Vault first (Auth references Vault for signing keys); Data second; Auth last. Each PR:
- Walks every persisted-record, contract-type, and `AuditEntry`-payload type in the Node.
- Adds `[Classification(...)]` to every public/internal property.
- Adds `[PiiField(...)]` to every PII-carrying field per ADR-0049 D2.
- Sets `Purpose` strings using `"{node}:{operation}"` convention.
- Builds with the analyzer rule from packet 03 firing at Warning — **zero warnings post-backfill** is the completion signal.
- Receives `security` specialist review (mandatory per ADR-0046 D2 + ADR-0049 D8) in addition to the generalist `review` agent.
- Solution-version bumps per invariant 27; per-package CHANGELOG only on packages with real marker additions (invariant 12/27).

### Packet 08 — Ops-sector backfill (`HoneyDrunk.Notify` → `HoneyDrunk.Communications`)

Two sequential PRs (plus a third if Pulse has persisted records — verify at branch time). Order: Notify first (Communications composes Notify per ADR-0019). Same procedure as packet 07.

**Special attention on Notify:** message-body fields are almost certainly Restricted with `[PiiField(Pii)]`; on templates whose content domain warrants it (health, financial, biometric), default to `SensitivePii`. The `security` specialist reviews these markers.

## Classification reminders

### Tier assignment (ADR-0049 D1)

- **Public** — intentionally world-readable.
- **Internal** — operational; studio-operator only; no tenant attribution.
- **Confidential** — tenant-attributable; tenant isolation enforced; not user-identifying.
- **Restricted** — PII, secrets, payment, message bodies, journal text, location, photos. Encrypted at rest; access logged; forbidden in observability without explicit carve-out.
- **Default to Restricted** on ambiguity.

### PII sub-category (ADR-0049 D2)

- **Pii** — identifies a natural person: name, email, IP address, behavioral telemetry, device ID.
- **SensitivePii** — Article 9 special category: government ID, financial-account credential, biometric, precise geolocation, health, religion, political opinion, racial/ethnic origin, trade-union membership, children's data, full PAN. **REQUIRES** explicit consent (or one of the narrow Article 9(2)(a-j) bases). **NEVER appears in audit channel** even as tokens (invariant 83).
- **Pseudonymous** — opaque Grid-scoped identifier with separately-held mapping (PrincipalId, TenantId, hashed-email idempotency key, agent-execution correlation IDs).

### "Field that should not exist" workflow

If the executor encounters a field that the Node should not be storing (e.g. a debug field capturing a full request body):
1. Mark it `[Classification(DataClass.Restricted)]` to surface to the security reviewer.
2. Open a separate follow-up issue in the target repo tracking the field's removal.
3. **Do NOT delete the field in this packet's PR.** Mark-and-flag only.

## Human steps within Wave 4

For each Node release between sequential PRs:
1. After the PR merges, push the git release tag (operator action).
2. Wait for the package to land on the feed before opening the next Node's PR.

Vault → Data → Auth → Notify → Communications, with a release between each.

The `security` specialist invocation on each PR is also a human action (per ADR-0046 D1 manual invocation at v1).

## What Wave 5 will do (preview)

- Packet 09: Populate `catalogs/data-classification.json` from the post-backfill marker surface; annotate `catalogs/contracts.json`.
- Packet 10: Flip the Standards analyzer from `Warning` to `Error` (after a 30-day window from packet 03's merge); wire `hive-sync` to reconcile the catalog nightly.
- Packet 11: Update `.claude/agents/security.md` (D1–D6 rubric), `.claude/agents/review.md` (D3 category 9 checklist), and author `.claude/agents/database.md`.

Wave 6 packet 12 (DPA/TIA/DPF — `Actor=Human`) runs in parallel from packet 00's merge onward; doesn't depend on backfill.
