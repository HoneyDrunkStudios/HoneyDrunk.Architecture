---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0049", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0049"]
wave: 2
initiative: adr-0049-pii-classification
node: honeydrunk-kernel
---

# Add [Classification] and [PiiField] attributes + DataClass/PiiCategory enums to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0049 D4 field-marking contract surface to `HoneyDrunk.Kernel.Abstractions`: the `ClassificationAttribute` and `PiiFieldAttribute` attributes, the `DataClass` enum (Public / Internal / Confidential / Restricted), and the `PiiCategory` enum (Pii / SensitivePii / Pseudonymous). All pure contracts — zero HoneyDrunk runtime dependencies. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution within this initiative.

## Context
ADR-0049 D4 commits **mechanical, field-level marking** as the data-classification enforcement mechanism. Naming conventions (`*Email`, `_pii_*`) were considered and rejected: they fail on aliased types, on records reshaped at boundaries, and on transitive payloads inside `Dictionary<string, object>` bags. Attributes are reflection-discoverable, type-checkable by analyzers, and explicit at the point of declaration. The cost is a one-line annotation per field; the benefit is mechanical enforceability across:

- **Log scrubbers** in `HoneyDrunk.Pulse`'s Azure Monitor sink — reflect over emitted log payloads; properties carrying `[PiiField(Pii | SensitivePii)]` are replaced with a redaction marker before the Azure Monitor exporter ships the line. (Packet 04.)
- **Audit redactor** in `HoneyDrunk.Audit` — on `AuditEntry` data-change emit, walk `Before`/`After` payloads; `[PiiField(Pii)]` → pseudonymous-token form; `[PiiField(SensitivePii)]` → `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` → as-is. (Packet 05.)
- **Error reporter** in `HoneyDrunk.Pulse`'s `IErrorReporter` backing — exception context dictionaries and custom dimensions walked; same scrubbing as logs. (Packet 04.)
- **Export jobs / DSAR** — `[PiiField]`-marked fields inventoried into the export manifest. (Future, ADR-0050.)
- **Analyzer rule** in `HoneyDrunk.Standards` — unmarked properties on records persisted by `HoneyDrunk.Data` or shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange` are an error; explicit `[Classification(DataClass.Public)]` is the way to opt out. (Packet 03.)

The contracts live in `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `IGridContext`, `TenantId`, and (per ADR-0042) `IGridMessageEnvelope` / `IIdempotencyStore`. This packet adds **attributes and enums only**; the analyzer rule lives in `HoneyDrunk.Standards` (packet 03), and the redactor implementations live in `HoneyDrunk.Pulse` and `HoneyDrunk.Audit` (packets 04, 05). Splitting attributes-from-runtime keeps `HoneyDrunk.Kernel.Abstractions` honest under invariant 1 (Abstractions have zero runtime dependencies on other HoneyDrunk packages).

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (per the kernel-adoption-alignment initiative tracker). If ADR-0042's packet 02 lands first and bumps to 0.8.0, this packet bumps from there to 0.9.0; if this packet lands first, it bumps to 0.8.0. The bumping packet for this initiative within `HoneyDrunk.Kernel` follows invariant 27 — every non-test `.csproj` in the solution moves to the same new version in one commit; subsequent Kernel-touching packets in this initiative (none currently planned beyond this one) would append to the in-progress CHANGELOG entry only.

> **Coordination note with ADR-0042.** ADR-0042's idempotency rollout also bumps `HoneyDrunk.Kernel.Abstractions`. If both initiatives land their Kernel changes in the same window, the executor must read the current `HoneyDrunk.Kernel` version at branch time and bump from there. Per invariant 27, all non-test `.csproj` files in the Kernel solution move to the same new version in a single commit. The agent does not push the git release tag — that is the human's post-merge step.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new types:
  - `DataClass` (enum) — `Public`, `Internal`, `Confidential`, `Restricted`.
  - `PiiCategory` (enum) — `Pii`, `SensitivePii`, `Pseudonymous`.
  - `ClassificationAttribute` (`AttributeUsage(Property | Field | Parameter, AllowMultiple = false, Inherited = true)`) — single-argument constructor taking `DataClass`; exposes a `Classification` read-only property.
  - `PiiFieldAttribute` (`AttributeUsage(Property | Field | Parameter, AllowMultiple = false, Inherited = true)`) — single-argument constructor taking `PiiCategory`; exposes a `Category` read-only property and an optional `Purpose` mutable string property (GDPR Article 5(1)(b) purpose-limitation tag).
- All non-test `.csproj` files in the solution version-bumped to the next minor (invariant 27).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` gets a new minor-version entry.

## Proposed Implementation
1. **`DataClass`** — `public enum DataClass { Public, Internal, Confidential, Restricted }`. Order matches ADR-0049 D1's handling-rigor order. XML-doc each value with the D1 definition (one sentence per tier).
2. **`PiiCategory`** — `public enum PiiCategory { Pii, SensitivePii, Pseudonymous }`. XML-doc each value with the D2 definition; `SensitivePii` doc must call out GDPR Article 9 special-category status and the `IAuditLog`-channel forbidden-entirely rule (invariant {N2} from packet 00).
3. **`ClassificationAttribute`** — sealed class deriving from `Attribute` with `[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter, AllowMultiple = false, Inherited = true)]`. Constructor: `public ClassificationAttribute(DataClass classification)`. Property: `public DataClass Classification { get; }` (read-only, set in constructor).
4. **`PiiFieldAttribute`** — sealed class deriving from `Attribute` with the same `AttributeUsage`. Constructor: `public PiiFieldAttribute(PiiCategory category)`. Properties: `public PiiCategory Category { get; }` (read-only); `public string? Purpose { get; set; }` (nullable, mutable to allow named-argument initialization `[PiiField(PiiCategory.Pii, Purpose = "notify:delivery")]` per ADR-0049 D4's worked example).
5. All public types/members get full XML documentation (invariant 13). The XML doc on `PiiFieldAttribute.Purpose` must explain the GDPR Article 5(1)(b) purpose-limitation tag intent and recommend short colon-delimited tokens (e.g. `"notify:delivery"`, `"billing:invoice"`, `"audit:correlation"`).
6. **No runtime logic.** No JSON/serializer hooks, no reflection helpers, no DI extensions, no analyzer logic. The reflection-and-redaction work lives in Pulse, Audit, and the consuming code; the compile-time check lives in `HoneyDrunk.Standards` (packet 03).
7. **`AllowMultiple = false`.** A property can be marked exactly once at each attribute kind. A property may carry both `[Classification(...)]` and `[PiiField(...)]` — they are different attribute types, both `AllowMultiple = false` against their own type, no conflict.
8. **Place the attributes in a sensible namespace.** ADR-0049 D4 does not name the namespace explicitly. Use `HoneyDrunk.Kernel.Abstractions.DataClassification` (mirrors the existing per-topic sub-namespaces — e.g. `HoneyDrunk.Kernel.Abstractions.Identity` for `TenantId`, `HoneyDrunk.Kernel.Abstractions.Tenancy` for `ITenantRateLimitPolicy`). Confirm by reading existing `HoneyDrunk.Kernel.Abstractions/` source folders before deciding.
9. Add a unit-test class in `HoneyDrunk.Kernel.Tests` (or `HoneyDrunk.Kernel.Abstractions.Tests` — match the repo's existing test-project convention) that verifies:
   - The attributes are applicable to properties, fields, and parameters but not to types or methods (compile-time targets check via reflection on `AttributeUsageAttribute`).
   - `AllowMultiple` is `false` on both.
   - `Inherited` is `true` on both.
   - `ClassificationAttribute.Classification` and `PiiFieldAttribute.Category` are read-only after construction.
   - `PiiFieldAttribute.Purpose` is `null` by default and settable via initializer syntax.
   - Each enum value is distinct and the enum order matches ADR-0049 D1/D2 (Public/Internal/Confidential/Restricted; Pii/SensitivePii/Pseudonymous).
10. Version-bump every non-test `.csproj` in the Kernel solution to the same new minor version in one commit. Read the current version first; if Kernel is `0.7.0` at branch time, bump to `0.8.0`; if ADR-0042 packet 02 has already shipped `0.8.0`, bump to `0.9.0`. The repo-level `CHANGELOG.md` gets a new `[X.Y.0]` entry for the version chosen. `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` gets a per-package entry (real change). `HoneyDrunk.Kernel/CHANGELOG.md` gets NO per-package entry in this packet — alignment bump only (invariant 12/27).
11. Update `HoneyDrunk.Kernel.Abstractions/README.md` — document the new data-classification attributes and enums in the public-API section, with the worked example from ADR-0049 D4 (the `Recipient` record showing `[Classification]` + `[PiiField]` together).

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/DataClassification/` (new folder if it does not exist) — new files for the two enums and two attributes (one per type per the repo's existing file-per-type convention).
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump.
- All other non-test `.csproj` files in the Kernel solution — version bump (alignment).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Tests` (or `HoneyDrunk.Kernel.Abstractions.Tests`) — unit tests for the attributes/enums.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions. `Attribute`, `AttributeUsageAttribute`, and the enum keyword come from the BCL. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- The unit-test project follows the repo's existing test stack (per ADR-0047 unit-test discipline once that initiative lands); no new packages introduced by this packet beyond what the test project already references.

## Boundary Check
- [x] `ClassificationAttribute`, `PiiFieldAttribute`, `DataClass`, `PiiCategory` are Kernel-Abstractions contracts per ADR-0049 D4. Routing rule "context, GridContext, NodeContext, ... CorrelationId → HoneyDrunk.Kernel" applies (the Abstractions package is the zero-dependency contract layer; this is the same placement as `IGridContext` and `TenantId`).
- [x] No new HoneyDrunk runtime dependency. Pure contract types.
- [x] Attributes and enums only; the analyzer rule (packet 03), the Pulse-side redactor (packet 04), and the Audit-side redactor (packet 05) are separate packets.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `DataClass` enum with values `Public`, `Internal`, `Confidential`, `Restricted` (in that order)
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `PiiCategory` enum with values `Pii`, `SensitivePii`, `Pseudonymous` (in that order)
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes sealed `ClassificationAttribute` with `[AttributeUsage(Property | Field | Parameter, AllowMultiple = false, Inherited = true)]` and a `DataClass Classification { get; }` property set via constructor
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes sealed `PiiFieldAttribute` with the same `AttributeUsage`, a `PiiCategory Category { get; }` property set via constructor, and a `string? Purpose { get; set; }` mutable property defaulting to `null`
- [ ] All new public types/members have XML documentation; the `SensitivePii` enum doc-comment calls out GDPR Article 9 + invariant {N2} (never appears in audit even as redaction-token)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1)
- [ ] Every non-test `.csproj` in the Kernel solution is at the new same minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[X.Y.0]` entry dated to the merge, describing the data-classification attribute surface
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has a per-package entry describing the attributes (real change)
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` has NO entry (no functional change in this packet — alignment bump only, per invariant 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new attributes and enums, with the ADR-0049 D4 worked example
- [ ] Unit tests in the Kernel test project verify attribute targets, `AllowMultiple = false`, `Inherited = true`, read-only properties, default `Purpose = null`, and enum ordering
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new attributes/enums are additive, paired with the minor-version bump

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0049 D4 — Field-level marking via attributes.** Two attributes (`ClassificationAttribute`, `PiiFieldAttribute`) and two enums (`DataClass`, `PiiCategory`) in `HoneyDrunk.Kernel.Abstractions`. Worked example:

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

**ADR-0049 D1 — Four-tier taxonomy.** `DataClass` enum order = Public ⊂ Internal ⊂ Confidential ⊂ Restricted in terms of handling rigor.

**ADR-0049 D2 — PII sub-taxonomy.** `PiiCategory` covers PII (Article 4 personal data), Sensitive PII (Article 9 special category — explicit consent or one of the Article 9(2) bases required), Pseudonymous (Article 4(5) — not exempt from regulation but a risk-mitigation measure).

**ADR-0049 D4 — Why attributes and not naming convention.** Naming conventions (`*Email`, `_pii_*`) fail on aliased types, on records reshaped at boundaries, and on transitive payloads inside `Dictionary<string, object>` bags. Attributes are reflection-discoverable, type-checkable by analyzers, and explicit at the point of declaration.

**ADR-0049 D5 — Consumers of the attributes.** Pulse log scrubbers, Audit redactor, Pulse error reporter, Export jobs, Test canaries, Standards analyzer rule. This packet only ships the contract surface; the consumers land in packets 03–06.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted; the BCL is fine. No DI extension methods, no JSON helpers, no analyzer logic — those each have their own home.
- **Invariant 4 — DAG with Kernel at the root.** No reference to any other HoneyDrunk runtime package.
- **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — All projects in a solution share one version and move together.** Every non-test `.csproj` in the Kernel solution bumps to the same new minor version in one commit. Partial bumps are forbidden.
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment bump only) gets none.
- **Records drop the `I`, interfaces keep it, attributes keep the `Attribute` suffix.** `ClassificationAttribute` and `PiiFieldAttribute` follow the .NET convention; they are referenced in source as `[Classification(...)]` and `[PiiField(...)]` (the compiler strips the suffix).
- **No analyzer logic in this packet.** Packet 03 ships the analyzer rule in `HoneyDrunk.Standards`. If reflection helpers are tempting here, push back — Pulse and Audit each own their own reflection walk against these attributes; Kernel.Abstractions stays declarative.
- **Coordination with ADR-0042.** If ADR-0042 packet 02 ships `HoneyDrunk.Kernel` `0.8.0` before this packet, this packet bumps to `0.9.0`. Read the current version at branch time and bump from there. Land in one commit per invariant 27.

## Labels
`feature`, `tier-2`, `core`, `adr-0049`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0049 D4 field-marking contract surface (`[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory`) to `HoneyDrunk.Kernel.Abstractions` and bump the `HoneyDrunk.Kernel` solution one minor version.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the attribute surface every other packet in this initiative compiles against.
- Feature: ADR-0049 Data Classification rollout, Wave 2 (Phase 1 contract foundation).
- ADRs: ADR-0049 D4 (primary), ADR-0049 D1/D2 (taxonomy backing the enums), ADR-0008 (packet conventions), ADR-0035 (additive minor-bump policy).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0049 Accepted and its invariants live before the attributes are built against them.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). No reference to any runtime package.
- Attributes and enums only — no DI extensions, no reflection helpers, no analyzer logic.
- Bump every non-test `.csproj` in the solution to the same new minor version in one commit (invariant 27).
- Per-package CHANGELOG entries only for `HoneyDrunk.Kernel.Abstractions` (real change). `HoneyDrunk.Kernel` is alignment-only — no per-package entry.
- Read the current Kernel version at branch time; if ADR-0042 packet 02 has already shipped `0.8.0`, bump to `0.9.0`.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/DataClassification/` — new attribute and enum files.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Every non-test `.csproj` for the version bump.

**Contracts:**
- `ClassificationAttribute` (new sealed Attribute) — applied to Property/Field/Parameter; `AllowMultiple = false`; `Inherited = true`; carries `DataClass Classification`.
- `PiiFieldAttribute` (new sealed Attribute) — same target/multiplicity/inheritance; carries `PiiCategory Category` and optional `string? Purpose`.
- `DataClass` (new enum) — `Public`, `Internal`, `Confidential`, `Restricted`.
- `PiiCategory` (new enum) — `Pii`, `SensitivePii`, `Pseudonymous`.
