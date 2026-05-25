# Handoff — Wave 2: Attribute Foundation Complete

**Wave:** 1 → 2 transition
**Initiative:** `adr-0049-pii-classification`
**ADR:** ADR-0049

This is the wave-transition baton: read once, execute Wave 2 packets, then move on.

## What landed in Wave 1

- **Packet 00** — ADR-0049 flipped to **Accepted**. `constitution/invariants.md` updated:
  - **Invariant 47** amended: the phrase "sensitive fields" now reads "sensitive fields (as defined by ADR-0049 D2 — fields marked `[PiiField(SensitivePii)]`)". The audit-append redaction mandate is preserved.
  - **Invariant 82** added (Data Classification Invariants section): every persisted field, every public API contract field, and every `AuditEntry` payload field carries a `[Classification]` attribute. Unmarked fields on records inside Restricted-class contexts are a CI gate failure under the `HoneyDrunk.Standards` analyzer rule. Explicit `[Classification(DataClass.Public)]` is the way to opt out.
  - **Invariant 59** added: `[PiiField(SensitivePii)]`-marked fields never appear in the audit channel, even as redaction-tokens. The Audit Node rejects appends whose Before/After payload reflection surfaces a SensitivePii marker. Only the field-name-and-class metadata may appear.
  - **Invariant 84** added: Restricted-class data never leaves the v1 Azure US East 2 region.
  - Numbers 82/83/84 are pre-reserved as ADR-0049's block in the 12-ADR batch; current verified max in the file (before packet 00 merged) was 53.
- **Packet 01** — `catalogs/data-classification.json` exists with the schema and an empty `nodes` object. Per ADR-0049 D9, this catalog is the operator-facing inventory of where classified data flows in the Grid. Population waits for Wave 4 backfill to complete.

## What Wave 2 builds

Two parallel packets, both depend on packet 00:

### Packet 02 — Kernel attributes and enums (`HoneyDrunk.Kernel`)

Add to `HoneyDrunk.Kernel.Abstractions`:

```csharp
public enum DataClass { Public, Internal, Confidential, Restricted }
public enum PiiCategory { Pii, SensitivePii, Pseudonymous }

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter, AllowMultiple = false, Inherited = true)]
public sealed class ClassificationAttribute : Attribute
{
    public ClassificationAttribute(DataClass classification);
    public DataClass Classification { get; }
}

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter, AllowMultiple = false, Inherited = true)]
public sealed class PiiFieldAttribute : Attribute
{
    public PiiFieldAttribute(PiiCategory category);
    public PiiCategory Category { get; }
    public string? Purpose { get; set; }
}
```

Namespace: `HoneyDrunk.Kernel.Abstractions.DataClassification` (mirrors `HoneyDrunk.Kernel.Abstractions.Identity` and `.Tenancy`). Confirm by reading existing folder layout.

This is the **first packet on the Kernel solution in this initiative** — it version-bumps every non-test `.csproj` to the same new minor version in one commit (invariant 27).

**Coordination with ADR-0042.** ADR-0042 also bumps Kernel (its packet 02 ships `IGridMessageEnvelope`/`IIdempotencyStore`). Read the current Kernel version at branch time; bump from there. The agent does NOT push the git release tag — that is a human step after merge.

Worked example (from ADR-0049 D4):

```csharp
public sealed record Recipient(
    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.Pii, Purpose = "notify:delivery")]
    string EmailAddress,

    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.SensitivePii, Purpose = "billing:invoice")]
    string? TaxIdentifier,

    [Classification(DataClass.Confidential)]
    TenantId Tenant,

    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.Pseudonymous, Purpose = "audit:correlation")]
    PrincipalId Subject
);
```

### Packet 03 — Standards analyzer rule at `Warning` severity (`HoneyDrunk.Standards`)

In `HoneyDrunk.Standards.Analyzers`, ship a Roslyn `DiagnosticAnalyzer` that fires on public/internal property declarations on records/classes in projects referencing `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions` when no `[Classification(...)]` attribute is present.

**Severity is `Warning` at v1.** Packet 10 in Wave 5 flips to `Error` after a 30-day adoption ramp (per ADR-0049 D10 Phase 1).

**Detection scope:** project-level PackageReference-based heuristic — over-fires acceptable at v1 (the developer adds `[Classification(DataClass.Public)]` to silence; one line; over-classification is safe). More-precise call-graph detection is a v2 follow-up.

**Attribute detection by FQN string,** not by package reference — the analyzer does NOT take a `PackageReference` on `HoneyDrunk.Kernel.Abstractions`. Match `HoneyDrunk.Kernel.Abstractions.DataClassification.ClassificationAttribute` as a string.

`[Classification(DataClass.Public)]` is a valid opt-out at any severity.

Bump every non-test `.csproj` in the Standards solution to the same new minor version (invariant 27).

## Constraints common to Wave 2

- **Invariant 1 — Abstractions zero-runtime-HoneyDrunk-dependency.** `HoneyDrunk.Kernel.Abstractions` takes only `Microsoft.Extensions.*`; the BCL is fine. No DI extensions, no reflection helpers, no analyzer logic — those each have their own home.
- **Invariant 4 — DAG.** Don't reference `HoneyDrunk.Transport` or anything else runtime from Kernel.Abstractions.
- **Invariant 13 — XML doc on all public APIs.** Especially: the `SensitivePii` enum value's doc-comment calls out GDPR Article 9 + invariant 59 (never in audit even as tokens).
- **Invariant 27 — All projects in a solution share one version.** Single commit per repo bump.
- **Invariant 12 — Per-package CHANGELOG only on packages with real changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment-only here) does not. `HoneyDrunk.Standards.Analyzers` gets an entry; other Standards packages don't.
- **Records drop the `I`, interfaces keep it, attributes keep the `Attribute` suffix.** `ClassificationAttribute` and `PiiFieldAttribute` follow the .NET convention.

## Human steps between Wave 2 and Wave 3

1. After packet 02 merges: push the `HoneyDrunk.Kernel` release tag (operator action).
2. After packet 03 merges: push the `HoneyDrunk.Standards` release tag (operator action).

Both packages must be on the package feed before Wave 3 packets 04 and 05 can build.

## What Wave 3 will do (preview)

- Packet 04: Pulse's Azure Monitor sink reflects on `[PiiField]` markers and redacts at the boundary.
- Packet 05: Audit's append path reflects on `[PiiField]` markers; redacts Pii to pseudonymous tokens; REJECTS SensitivePii (invariant 59).
- Packet 06: cross-boundary PII-scrubbing canary asserts end-to-end behavior.
