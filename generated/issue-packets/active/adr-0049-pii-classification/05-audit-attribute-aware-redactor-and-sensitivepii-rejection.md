---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "core", "adr-0049", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0049", "ADR-0030"]
wave: 3
initiative: adr-0049-pii-classification
node: honeydrunk-audit
---

# Wire attribute-aware redaction + SensitivePii rejection into HoneyDrunk.Audit's append path

## Summary
Extend the `HoneyDrunk.Audit` append path with an attribute-aware redactor: on every `IAuditLog.AppendAsync(AuditEntry)` call, walk `AuditEntry.DataChange.Before/After` and `AuditEntry.Metadata` payloads against the `[PiiField]` markers from packet 02. `[PiiField(Pii)]` fields become pseudonymous tokens (D6); `[PiiField(SensitivePii)]` fields are **rejected entirely** — the append fails with a typed error and a metadata-only audit entry is the only acceptable substitute. `[PiiField(Pseudonymous)]` passes through. This makes invariant 47's amended "sensitive fields" mandate concrete and turns invariant 83 (SensitivePii never in audit) into a hard runtime contract.

## Context
ADR-0030 D3 mandated "data-change details that include sensitive fields must be redacted before append" against an undefined "sensitive field" concept. ADR-0049 D2 defines them (`[PiiField(SensitivePii)]`), and ADR-0049 D5 binds the audit append path to the field-marking attributes. Two distinct redaction behaviors apply at the audit boundary:

- **PII fields (`[PiiField(Pii)]`)** — redacted to their **pseudonymous-token form**, not to a sentinel marker. The token-to-value mapping lives in the per-Node identity store (`HoneyDrunk.Auth`'s user store for Studio products; the per-app onboarding store for consumer products). This is the load-bearing mechanic for ADR-0049 D6 right-to-erasure: the audit record retains the token, which resolves through the identity-store row at read time; deletion of the identity-store row makes the token resolve to *nothing*, while the audit history "user did X at time T" remains intact and forensically useful.
- **Sensitive PII fields (`[PiiField(SensitivePii)]`)** — **never appear** in the audit channel, not even as tokens. This is stricter than the `Pii` case and is **mandatory** (invariant 83 from packet 00). Article 9 special-category data has no business in audit data-change details. The audit Node rejects the append entirely with a typed exception or returns a failure result, depending on `IAuditLog`'s existing error-shape contract.
- **Pseudonymous fields (`[PiiField(Pseudonymous)]`)** — pass through unchanged. Pseudonymous identifiers (`PrincipalId`, `TenantId`, hashed-email idempotency keys) are the audit channel's normal vocabulary.
- **`AuditEntry.Metadata` dictionary** — same walk, with the boxed-value reflection caveat: if a value presents as a raw `string` with no source-type metadata, the boundary cannot determine its classification from the bag alone. ADR-0049 D5 names this as **emitter-responsibility** (the emitter must not put raw-string PII in `Metadata` without pre-redacting). The audit redactor falls through and ships the raw value in that case, but the analyzer rule (packet 03) and emitter discipline (packets 07, 08 per-Node backfill) catch this at compile/review time.

The append-only-by-interface property of `IAuditLog` (ADR-0030 D7, invariant 47) is preserved: this packet adds *defensive validation and redaction at the append surface* — it does not add an update or delete method, does not weaken the durability contract, and does not touch read-side `IAuditQuery`.

The Audit Node is a live Node currently at v0.1.0 (Seed signal in `catalogs/nodes.json`; standup decided by ADR-0030/0031, in execution per the ADR-0031 standup track). Read the current `HoneyDrunk.Audit` repo layout at branch time:
- `HoneyDrunk.Audit.Abstractions` — exposes `IAuditLog`, `AuditEntry`, `IAuditQuery`, value types.
- `HoneyDrunk.Audit.Data` — Data-backed append-only store (per ADR-0031 D5).
- Possibly other packages — confirm at branch time.

The redactor logic lives in the **runtime append path** (the implementation behind `IAuditLog`), not in `HoneyDrunk.Audit.Abstractions`. Abstractions stays zero-runtime-dependency (invariant 1). The runtime package gains a runtime dependency on `HoneyDrunk.Kernel.Abstractions` (which it already has, for `IGridContext`/`TenantId`/etc.); the version bump aligns with packet 02's published version.

> **Coordination with packet 06 (canary).** Packet 06 ships the cross-Node canary that proves redaction end-to-end. The canary includes an `AuditEntry.DataChange` case asserting `[PiiField(Pii)]` becomes a token and `[PiiField(SensitivePii)]` causes the append to fail. Packet 06 depends on this packet.

## Scope
- `HoneyDrunk.Audit` repo — the runtime package that implements `IAuditLog` (typically `HoneyDrunk.Audit.Data` or a sibling runtime package; read the repo at branch time).
- New types:
  - `AuditPayloadRedactor` (internal sealed class) — walks `AuditEntry.DataChange.Before/After` and `AuditEntry.Metadata` payloads; applies the three redaction behaviors above; returns either a redacted `AuditEntry` or a typed-rejection result for SensitivePii.
  - `AuditPiiToken` (record, public, in `HoneyDrunk.Audit.Abstractions`) — a typed wrapper around the pseudonymous-token string. Exposed because reader/consumer code needs to recognize a token vs. a raw value when querying audit entries. Carries the token string and optionally a category discriminator. Final shape — read ADR-0030/0031 for whether a similar value type already exists, and reuse it if so; otherwise add a new one.
  - `SensitivePiiInAuditException` (or `AuditAppendResult.Rejected` enum variant — match `IAuditLog`'s existing error-shape contract; read at branch time) — the typed failure when an append carries a `[PiiField(SensitivePii)]`-marked field.
- The `IAuditLog` runtime implementation — calls `AuditPayloadRedactor` before persisting; on SensitivePii detection, fails the append with the typed result; emits its own operational telemetry (per ADR-0030 D9 one-way flow to Pulse) for the rejection so the operator sees it.
- The **pseudonymous-token derivation** — `AuditPayloadRedactor` does NOT compute the token itself; it delegates to an `IAuditTokenizer` interface that the runtime composition wires to the per-Node identity store. For v1, ship a stub `InMemoryAuditTokenizer` that derives a deterministic per-`(TenantId, FieldName, RawValue)` token (e.g. `SHA256` of those three concatenated with a salt) and stores the mapping in an InMemory dictionary; document that production deployments inject a real implementation that persists the mapping to the per-Node identity store. The ADR-0050 sibling tenant-lifecycle work will replace the stub with the real Auth-backed tokenizer.
- Tests — unit tests for the redactor's three outcomes, integration test for end-to-end append with mixed-marker `AuditEntry`.
- Version bump on the Audit solution; per-package CHANGELOG only on packages with real changes.

## Proposed Implementation

1. **`IAuditTokenizer`** (new interface in `HoneyDrunk.Audit.Abstractions`):
   ```
   public interface IAuditTokenizer
   {
       ValueTask<AuditPiiToken> TokenizeAsync(TenantId tenant, string fieldName, object? value, CancellationToken ct);
   }
   ```
   The interface is the seam between the Audit boundary and the per-Node identity-store mapping. v1 ships an `InMemoryAuditTokenizer` for tests and a stub-with-deterministic-hash for staging; ADR-0050's tenant-lifecycle work wires the real Auth-backed implementation. XML-doc the interface with the right-to-erasure mechanic explanation (per ADR-0049 D6).

2. **`AuditPiiToken`** (new record in `HoneyDrunk.Audit.Abstractions`):
   ```
   public sealed record AuditPiiToken(string Value)
   {
       public static AuditPiiToken FromString(string token);
       public override string ToString();
   }
   ```
   Wrapper around the opaque pseudonymous token string. Records drop the `I`; this is a record (Grid-wide naming rule). XML-doc explains the token resolves through `IAuditTokenizer` (and ultimately through the per-Node identity store).

3. **`AuditPayloadRedactor`** (internal sealed class in the runtime package):
   - Constructor takes `IAuditTokenizer` and `IGridContext` (for the `TenantId`).
   - `RedactAsync(AuditEntry entry, CancellationToken ct)` returns either a redacted `AuditEntry` or throws `SensitivePiiInAuditException` (or returns the matching `AuditAppendResult.Rejected` value — match existing error shape).
   - Walks `entry.DataChange?.Before` and `entry.DataChange?.After` via reflection (or via source-generated walker if the existing Audit runtime uses one — read at branch time).
   - For each property:
     - `[PiiField(SensitivePii)]` present → fail-fast (throw / return rejection).
     - `[PiiField(Pii)]` present → call `IAuditTokenizer.TokenizeAsync` and replace the property value with the resulting `AuditPiiToken`.
     - `[PiiField(Pseudonymous)]` present → pass-through (it is already a pseudonymous identifier).
     - No `[PiiField]` marker → pass-through (the field is not PII).
   - Walks `entry.Metadata` (dictionary) entries: if the value's runtime type has a `[PiiField]` marker on a property by the same key name, apply the same logic. If the value is a raw boxed `string` with no source-type metadata, fall through and emit the value as-is (emitter-responsibility per ADR-0049 D5).
   - The runtime emits its own operational telemetry on a rejection (per ADR-0030 D9, one-way flow to Pulse) so the operator sees `[REJECTED:SensitivePii in audit:{NodeId}:{Category}]` in App Insights. The telemetry payload carries the rejecting field's *name* and *classification* — NOT its value.

4. **`SensitivePiiInAuditException`** — typed exception derived from `InvalidOperationException` (or a more-specific Audit base exception if one exists). Carries:
   - The offending field name.
   - The classification (`SensitivePii`).
   - The category (`PiiCategory.SensitivePii`).
   - A message string explaining ADR-0049 D6 + invariant 83: "Sensitive PII may not appear in the audit channel even as redaction-tokens. Record the *fact* of the change via field-name and classification metadata only."

   If `IAuditLog.AppendAsync` returns a result type instead of throwing (e.g. `AuditAppendResult.Ok` / `AuditAppendResult.Rejected`), use the result-shape pattern instead.

5. **`IAuditLog` runtime implementation** — extend the existing implementation in `HoneyDrunk.Audit.Data` (or wherever it lives). On every `AppendAsync` call, run `AuditPayloadRedactor.RedactAsync(entry)` first, then persist the redacted entry. On a SensitivePii rejection, return the typed failure and emit operational telemetry; do NOT persist a partial audit entry.

6. **DI composition** — extend the existing `AddHoneyDrunkAudit` (or equivalent) DI extension to register `AuditPayloadRedactor` (singleton) and a default `InMemoryAuditTokenizer` (singleton). Document that production hosts inject a real `IAuditTokenizer` via DI before the InMemory one is consumed.

7. **Tests.**
   - `AuditPayloadRedactor`: each of the three `PiiField` markers produces the correct outcome.
   - SensitivePii in `Before`/`After`/`Metadata` all cause rejection.
   - Pseudonymous and unmarked fields pass through.
   - `AuditPiiToken` round-trips through the `IAuditTokenizer.TokenizeAsync` call (use the InMemory implementation in the test).
   - Integration test: emit an `AuditEntry` with a `[PiiField(Pii)]`-marked Before/After; assert the persisted entry shows the token form; assert the InMemory `IAuditTokenizer` mapping carries the original value.
   - Integration test: emit an `AuditEntry` with a `[PiiField(SensitivePii)]`-marked field; assert `AppendAsync` returns the rejection result; assert no entry was persisted.
   - Append-only-by-interface preserved: the existing contract-shape canary for `IAuditLog` (per invariant 49) must still pass — the new types are additive, not breaking.

8. **Version bump.** Bump every non-test `.csproj` in the Audit solution to the same new minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` gets a new `[X.Y.0]` entry. Per-package CHANGELOG entries on `HoneyDrunk.Audit.Abstractions` (new `IAuditTokenizer` interface + `AuditPiiToken` record) and on the runtime implementation package (real change). Other packages alignment-only — no per-package entries.

## Affected Files
- `HoneyDrunk.Audit.Abstractions/` — new `IAuditTokenizer` interface, new `AuditPiiToken` record, possibly an `AuditAppendResult` variant or `SensitivePiiInAuditException`.
- The Audit runtime package (`HoneyDrunk.Audit.Data` or sibling — read at branch time) — new `AuditPayloadRedactor` internal class, `InMemoryAuditTokenizer`, extended `IAuditLog` implementation, DI composition update.
- Tests in the Audit test projects.
- `HoneyDrunk.Audit.Abstractions/CHANGELOG.md`, `README.md`.
- The runtime package's `CHANGELOG.md`, `README.md`.
- Repo-level `HoneyDrunk.Audit/CHANGELOG.md`.
- Every non-test `.csproj` in the Audit solution — version bump.

## NuGet Dependencies
- **`HoneyDrunk.Audit.Abstractions`** — gains (or version-bumps the existing) `PackageReference` on `HoneyDrunk.Kernel.Abstractions` at the packet-02 version (needed for `PiiCategory` references in `IAuditTokenizer`/`AuditPiiToken` docs and signatures, and for `TenantId` which it likely already consumes). Per invariant 1 the Abstractions package may reference other Abstractions; this is consistent with how `HoneyDrunk.Notify.Cloud.Abstractions` (per ADR-0027 D3) and `HoneyDrunk.Audit.Abstractions` (per ADR-0031 D9) already reference Kernel.Abstractions.
- The Audit runtime package — version-bumps the existing `HoneyDrunk.Kernel.Abstractions` reference; no new packages.

## Boundary Check
- [x] All edits in `HoneyDrunk.Audit`. Routing: Audit owns the durable audit substrate per ADR-0030; the redactor lives at the append surface; new contracts in `HoneyDrunk.Audit.Abstractions` per invariant 48.
- [x] Downstream Nodes still depend only on `HoneyDrunk.Audit.Abstractions` (invariant 48 preserved). The new redactor logic lives in the runtime package.
- [x] No runtime dependency on Pulse — Audit's own operational telemetry flows one-way to Pulse per ADR-0030 D9; the rejection-telemetry emit uses the existing Pulse-emit path, not a new one.

## Acceptance Criteria
- [ ] `HoneyDrunk.Audit.Abstractions` ships `IAuditTokenizer` interface and `AuditPiiToken` record
- [ ] `HoneyDrunk.Audit.Abstractions` ships either `SensitivePiiInAuditException` or a new `AuditAppendResult` variant — match the existing error-shape contract; the agent chooses based on what already exists, and documents the choice in the PR
- [ ] The Audit runtime implementation calls `AuditPayloadRedactor.RedactAsync` before persisting every `AuditEntry`
- [ ] `[PiiField(Pii)]` fields in `Before`/`After`/`Metadata` are replaced with `AuditPiiToken` values
- [ ] `[PiiField(SensitivePii)]` in any of `Before`/`After`/`Metadata` causes the append to fail with the typed result — no partial entry is persisted
- [ ] `[PiiField(Pseudonymous)]` and unmarked fields pass through unchanged
- [ ] On a SensitivePii rejection, operational telemetry is emitted to Pulse carrying the offending field name and classification (NOT the value)
- [ ] DI composition registers `AuditPayloadRedactor` and a default `InMemoryAuditTokenizer`; production hosts can override `IAuditTokenizer` via DI
- [ ] Append-only-by-interface preserved: `IAuditLog` exposes no new update or delete method; the contract-shape canary (invariant 49) still passes
- [ ] Unit tests cover all three marker outcomes plus the InMemory tokenizer round-trip
- [ ] Integration tests cover the persisted-token case and the rejected-SensitivePii case
- [ ] `HoneyDrunk.Audit.Abstractions` and the runtime package each get a per-package CHANGELOG entry (real changes); other Audit-solution packages are alignment bumps with no per-package entries (invariant 12/27)
- [ ] Repo-level `CHANGELOG.md` has a new `[X.Y.0]` entry
- [ ] Every non-test `.csproj` in the Audit solution is at the same new minor version in a single commit (invariant 27)

## Human Prerequisites
- [ ] **CRITICAL — Audit runtime code must exist before this packet can execute.** `HoneyDrunk.Audit` is currently `signal: Seed` in `catalogs/nodes.json` at authoring time (2026-05-24). The runtime targets this packet edits (`HoneyDrunk.Audit.Abstractions` already shipping `IAuditLog`/`AuditEntry`, the Data-backed runtime implementation per ADR-0031 D5, the existing `AddHoneyDrunkAudit` composition, the existing operational-telemetry one-way Pulse emit path per ADR-0030 D9) are commitments of **ADR-0030 (Audit Substrate) Phase-1** and **ADR-0031 (Audit Node Standup)** that have **not yet shipped runtime code**. This packet is **blocked on cross-init prereqs**:
  - **ADR-0031 Phase 1 standup must have shipped** the runtime implementation of `IAuditLog`, the Data-backed append store, the existing composition extension, and the Pulse-emit operational-telemetry path.
  - Audit's `signal` in `catalogs/nodes.json` must have advanced from `Seed` to at least `Standup` with the runtime packages on the package feed.
  - Verify both at branch time before opening any branch on `HoneyDrunk.Audit`. If incomplete, **do not execute this packet** — file the dependency back in the dispatch plan and surface to the Studio operator. The reviewer flagged this packet as blocked on Seed-signal repos; respecting that block is mandatory.
- [ ] **Confirm the published version of `HoneyDrunk.Kernel.Abstractions` carrying the packet-02 attributes is on the package feed.** Same gate as packet 04 — a human release tag on `HoneyDrunk.Kernel` is required between packet 02 merging and this packet building.

## Referenced ADR Decisions
**ADR-0049 D5 — Audit append redaction.** `AuditEntry.DataChange.Before/After` walked unconditionally: `[PiiField(Pii)]` → pseudonymous token; `[PiiField(SensitivePii)]` → `[REDACTED:sensitive]` — and (this packet's stricter interpretation, per D6 + invariant 83) **the SensitivePii case is a rejection, not a redaction**. `[PiiField(Pseudonymous)]` → as-is. `Metadata` walked the same way with the boxed-value fall-through documented as emitter-responsibility.

**ADR-0049 D6 — Right-to-erasure mechanic.** `AuditEntry.Actor` and `AuditEntry.Target` carry `PrincipalId` and `TenantId` (pseudonymous identifiers per D2). `[PiiField(Pii)]` fields in `AuditEntry.Metadata` and `AuditEntry.DataChange.Before/After` are stored as **pseudonymous tokens at emit time**, not as raw values. The token-to-value map sits in the per-Node identity store. Same erasure mechanic: deleting the identity-store row makes the token resolve to nothing; the audit history remains intact.

**ADR-0049 D6 — SensitivePii exception.** "`[PiiField(SensitivePii)]` fields are **never** emitted to the audit channel even as tokens. Article 9 special-category data cannot appear in the audit record's data-change body at all; the audit entry records *that* a Sensitive PII field was changed (field name, classification, source Node), not the values. This is stricter than the `Pii` case and is mandatory."

**ADR-0030 D3 — Audit append redaction (extended).** Originally "data-change details that include sensitive fields must be redacted before append" against an undefined concept. ADR-0049 D5 makes it concrete via the `[PiiField]` attribute; this packet implements it.

**ADR-0030 D6/D7 — Append-only-by-interface.** `IAuditLog` exposes no update method and no delete method. This packet preserves that property — it adds defensive validation and redaction at the *append* surface, not new mutation surfaces.

**Invariant 47 (amended in packet 00).** "Data-change details that include sensitive fields (as defined by ADR-0049 D2 — fields marked `[PiiField(SensitivePii)]`) must be redacted before append." This packet ships the runtime enforcement.

**Invariant 83 (added in packet 00).** "`[PiiField(SensitivePii)]`-marked fields never appear in the audit channel, even as redaction-tokens. The Audit Node rejects appends whose `Before`/`After` payload reflection surfaces a `SensitivePii` marker. Only the field-name-and-class metadata may appear."

**Invariant 48 — Downstream consumers compile against `HoneyDrunk.Audit.Abstractions` only.** The new `IAuditTokenizer` and `AuditPiiToken` ship in Abstractions; the runtime stays internal to the Audit Node. Consumers do not reference the runtime package in production composition.

**Invariant 49 — Contract-shape canary on `HoneyDrunk.Audit.Abstractions`.** The new interface and record are additive minor-version changes — the canary must remain green paired with the minor-version bump.

## Constraints
- **SensitivePii is a rejection, not a redaction.** Invariant 83's "never appears in the audit channel, even as redaction-tokens" rule means the audit Node refuses the append outright. Do not soften this to a `[REDACTED:sensitive]` write — that would leak the *fact* of the value into the audit body in a way invariant 83 forbids. The audit entry records that a SensitivePii field was changed (field name and classification) ONLY through the operational-telemetry rejection signal, never as a persisted audit body.
- **Append-only-by-interface preserved.** `IAuditLog` adds no update or delete method. The new types are additive (new interface, new record, new exception).
- **Tokenizer is an injected seam.** Audit does not own the identity store. v1 ships an `InMemoryAuditTokenizer` stub; ADR-0050's tenant-lifecycle work wires the real Auth-backed implementation. Document this in code comments and README.
- **Operational telemetry emit on rejection.** The Audit Node's own operational telemetry flows one-way to Pulse per ADR-0030 D9 — no runtime dependency on Pulse. The rejection signal uses the existing Pulse-emit pathway in the Audit runtime (created when the Audit Node stood up). The payload carries field name + classification, never the value.
- **Invariant 1 / Invariant 48.** `HoneyDrunk.Audit.Abstractions` may reference only `Microsoft.Extensions.*` abstractions and `HoneyDrunk.Kernel.Abstractions` (the established carve-out for Kernel-defined primitives like `TenantId`). The runtime types (`AuditPayloadRedactor`, `InMemoryAuditTokenizer`) stay in the runtime package.
- **Invariant 27 — All projects in a solution share one version.** Bump every non-test `.csproj` in `HoneyDrunk.Audit` to the same new minor version in one commit.
- **Invariant 12 — Per-package CHANGELOGs only for packages with real changes.** `HoneyDrunk.Audit.Abstractions` and the runtime package each get an entry. Other Audit-solution packages are alignment-only.

## Labels
`feature`, `tier-2`, `core`, `adr-0049`, `wave-3`

## Agent Handoff

**Objective:** Ship attribute-aware audit-redaction with SensitivePii rejection in `HoneyDrunk.Audit`'s append path, including the `IAuditTokenizer` seam in Abstractions.

**Target:** `HoneyDrunk.Audit`, branch from `main`.

**Context:**
- Goal: Bind ADR-0030 D3's "redact sensitive fields before append" to the field-marking attributes; make invariant 83 (SensitivePii never in audit) a runtime contract.
- Feature: ADR-0049 Data Classification rollout, Wave 3 (Phase 3 redactor integrations).
- ADRs: ADR-0049 D5/D6 (primary), ADR-0030 D3/D6/D7 (audit substrate boundary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `ClassificationAttribute` and `PiiFieldAttribute` exist in `HoneyDrunk.Kernel.Abstractions` and are published to the package feed.

**Constraints:**
- SensitivePii is a rejection, not a redaction. Invariant 83 forbids any audit body containing SensitivePii fields, even as redaction-tokens.
- Append-only-by-interface preserved — no new update or delete method on `IAuditLog`.
- Tokenizer is an injected seam (`IAuditTokenizer`); v1 InMemory stub, production-real arrives with ADR-0050.
- Rejection emits operational telemetry to Pulse via the existing one-way emit path; payload carries field name + classification, never the value.
- Invariant 27 bump on the Audit solution; per-package CHANGELOG entries on `HoneyDrunk.Audit.Abstractions` and the runtime package (real changes); other packages are alignment-only.
- The `HoneyDrunk.Kernel.Abstractions` reference must match the packet-02-published version.

**Key Files:**
- `HoneyDrunk.Audit.Abstractions/` — new `IAuditTokenizer`, `AuditPiiToken`, and the error-shape addition.
- The Audit runtime package — new `AuditPayloadRedactor`, `InMemoryAuditTokenizer`, extended `IAuditLog` impl.
- Tests in `HoneyDrunk.Audit`'s test projects.
- Per-package CHANGELOGs and READMEs; repo-level `CHANGELOG.md`.

**Contracts:**
- `IAuditTokenizer` (new interface in Abstractions) — `TokenizeAsync(TenantId, fieldName, value, ct) -> ValueTask<AuditPiiToken>`.
- `AuditPiiToken` (new record in Abstractions) — opaque pseudonymous-token wrapper.
- The error-shape addition (`SensitivePiiInAuditException` or `AuditAppendResult.Rejected` variant) — the typed failure for SensitivePii-in-audit attempts.
