---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "meta", "adr-0049", "wave-2"]
dependencies: ["work-item:02"]
adrs: ["ADR-0049"]
wave: 2
initiative: adr-0049-pii-classification
node: honeydrunk-standards
---

# Ship the unmarked-field classification analyzer rule in HoneyDrunk.Standards

## Summary
Add a new Roslyn analyzer rule to `HoneyDrunk.Standards.Analyzers` (per ADR-0049 D4) that flags **unmarked properties on types in Restricted-class contexts** — specifically, properties on records persisted by `HoneyDrunk.Data` repositories or shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange`. Unmarked is an error after a 30-day warning grace; explicit `[Classification(DataClass.Public)]` is the way to opt out. This catches "developer added a new field and forgot to classify it" at compile time.

## Context
ADR-0049 D4 commits the **mechanical enforceability** posture: attributes are declarative at the point of declaration; the analyzer rule is the compile-time check that catches drift. Without the analyzer:

- An unmarked field on a persisted record silently inherits no classification at all. The Pulse log scrubber and the Audit redactor (packets 04, 05) walk reflection looking for `[PiiField]` markers — they cannot see what is not declared. Field added without a marker = field shipped without redaction = PII in telemetry.
- The "missing classification" failure mode is the highest-risk regression in the entire ADR-0049 surface, because it is silent — no test fails, no runtime exception fires, the field just slips out into log/audit/error channels until someone notices.

ADR-0049 D10 commits a phased rollout for the analyzer: **warnings for the first 30 days, errors after.** This packet ships the rule in warning mode; packet 10 flips it to error mode at the 30-day mark (and wires the `hive-sync` reconciliation against `catalogs/data-classification.json`). The 30-day window gives the per-Node backfill packets (07, 08) time to land before unmarked-field surface fails CI.

`HoneyDrunk.Standards.Analyzers` is the existing analyzer-host project in the Standards repo. It already ships at least the `HoneyDrunk.Standards` StyleCop + EditorConfig analyzer set referenced Grid-wide (invariant 26). The new classification analyzer is the same class of artifact — a Roslyn `DiagnosticAnalyzer` shipped as part of the existing analyzer package, distributed via `PrivateAssets: all` to consuming projects. No new analyzer package is created.

> **Coordination note with ADR-0047.** ADR-0047 (Testing Patterns and Tooling) ships a separate analyzer rule (the `Thread.Sleep`-in-tests rule) in `HoneyDrunk.Standards.Analyzers`. Both analyzers live in the same project. Read the current analyzer file layout in `HoneyDrunk.Standards.Analyzers/` at branch time and place the new rule alongside the existing rules using the same per-rule file structure.

## Scope
- `HoneyDrunk.Standards.Analyzers/` — new `DiagnosticAnalyzer` for the unmarked-field rule, with associated diagnostic descriptor, analyzer registration, and tests in `HoneyDrunk.Standards.Tests` (or the equivalent analyzer-tests project).
- A new diagnostic ID — pick the next free ID in the `HD` (or whatever prefix the existing Standards analyzers use) sequence; verify by reading `HoneyDrunk.Standards.Analyzers/` for existing diagnostic registrations.
- `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` — per-package entry describing the new rule.
- Repo-level `HoneyDrunk.Standards/CHANGELOG.md` — new minor-version entry (invariant 27 — every non-test `.csproj` in the Standards solution bumps to the same new version in one commit).
- `HoneyDrunk.Standards.Analyzers/README.md` — document the new rule, its detection scope, the warning-vs-error phase, and the `[Classification(DataClass.Public)]` opt-out.

## Proposed Implementation

1. **Detection scope.** The analyzer fires on **public/internal `record` and `class` declarations** whose type qualifies as a Restricted-class context. ADR-0049 D4 names two qualification criteria:
   - (a) Records persisted by `HoneyDrunk.Data` repositories — concretely, types that appear as the generic argument to `IRepository<T>` or `IUnitOfWork<T>` (or whatever the canonical Data persistence interfaces are at branch time; read `HoneyDrunk.Data.Abstractions` source to confirm).
   - (b) Types shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange` — types referenced from `AuditEntry.DataChange.Before` and `AuditEntry.DataChange.After` payload shapes.

   v1 detection heuristic (cheapest correct option): the analyzer flags **any record/class declaration in a project that takes a `PackageReference` to `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions`**. This over-fires (some types in those projects are not persisted), but the false-positive is benign — the developer adds `[Classification(DataClass.Public)]` (one line, costs nothing) or the correct higher classification. Over-classification is safe per ADR-0049 D1.

   A more-precise v2 (call graph through `IRepository<T>` generic positions) is documented as a follow-up, not built here. The over-firing variant is cheaper, ships sooner, and aligns with ADR-0049 D1's default-to-Restricted disposition.

2. **What's "unmarked".** A property on a qualifying type is unmarked when it carries **no `ClassificationAttribute`** (with any `DataClass` value). The presence of `[Classification(DataClass.Public)]` is a valid opt-out — Public-class data is fine in any channel, the developer just has to declare the intent. The presence of `[Classification(...)]` with any other tier is also fine (the analyzer's concern is presence-or-absence, not which tier).

3. **Diagnostic descriptor.**
   - **ID:** the next free `HD####` (or current Standards prefix) ID. Confirm by reading existing analyzer registrations.
   - **Severity at v1:** `Warning` (per ADR-0049 D10 — warnings for the first 30 days, errors after).
   - **Title:** "Property in a Restricted-class context is missing a `[Classification]` attribute."
   - **MessageFormat:** "Property `{0}` on type `{1}` has no `[Classification]` attribute. ADR-0049 D4 requires every persisted-record/audit-payload field to declare its classification. Apply `[Classification(DataClass.Public)]` if the field is intentionally public; otherwise apply the correct tier (`Internal`, `Confidential`, `Restricted`)."
   - **Category:** "Naming" or "Security" — match the existing Standards-analyzer categorization convention.
   - **HelpLinkUri:** link to a section in `HoneyDrunk.Standards.Analyzers/README.md` describing the rule (anchor like `#unmarked-classification`); or to the ADR-0049 file on GitHub.

4. **Implementation pattern.** Use `RegisterSymbolAction(... , SymbolKind.NamedType)` to inspect type declarations; for each qualifying type, walk its public/internal property symbols and emit the diagnostic for any property without a `ClassificationAttribute` (or its FQN equivalent). Cross-reference the existing analyzer in the project for the registration boilerplate; do not invent a new pattern.

5. **`Inherited`-aware.** `ClassificationAttribute` has `Inherited = true`. If a base type has `[Classification(...)]` on a property and a derived type overrides it without re-declaring, the inherited attribute satisfies the rule. Use `Compilation.GetAttributes(includeInherited: true)`-equivalent semantics — confirm Roslyn's symbol API gives this behavior or walk the base type chain manually.

6. **Tests.** Add analyzer tests in `HoneyDrunk.Standards.Tests` (or the analyzer-tests project). Cover:
   - Unmarked property on a record in a project referencing `HoneyDrunk.Data` → warning fires.
   - `[Classification(DataClass.Public)]` on the property → no warning.
   - `[Classification(DataClass.Restricted)]` on the property → no warning.
   - `[PiiField(...)]` without `[Classification]` → warning still fires (the two attributes are independent; the analyzer checks for `ClassificationAttribute` specifically, not `PiiFieldAttribute`).
   - Record in a project that does NOT reference `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions` → no warning (out of scope).
   - Inherited attribute via base type → no warning on derived (Inherited = true is respected).
   - Field (not property) — the analyzer focuses on properties at v1; if the existing test scaffolding makes field-coverage trivial, include it; if not, fields are a v2 enlargement.

7. **Version bump.** Bump every non-test `.csproj` in the `HoneyDrunk.Standards` solution to the same new minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` gets a new `[X.Y.0]` entry. `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` gets a per-package entry. Other non-test packages (e.g. the EditorConfig/Standards meta-package) are alignment bumps — no per-package entry unless they have a functional change in this packet (they don't).

8. **README update.** `HoneyDrunk.Standards.Analyzers/README.md` documents the new rule: detection scope, severity progression (warning at v1 → error at 30-day mark per packet 10), the opt-out (`[Classification(DataClass.Public)]`), and a "Why this rule exists" link to ADR-0049 D4.

## Affected Files
- `HoneyDrunk.Standards.Analyzers/` — new analyzer source file(s); diagnostic registration.
- `HoneyDrunk.Standards.Analyzers/CHANGELOG.md`, `HoneyDrunk.Standards.Analyzers/README.md`.
- `HoneyDrunk.Standards.Tests/` (or the analyzer-tests project) — new tests.
- Repo-level `HoneyDrunk.Standards/CHANGELOG.md`.
- Every non-test `.csproj` in the Standards solution — version bump.

## NuGet Dependencies
- **`HoneyDrunk.Standards.Analyzers`** — already references `Microsoft.CodeAnalysis.CSharp` (or `Microsoft.CodeAnalysis.Analyzers`) at the appropriate version for Roslyn analyzers. Read the existing `.csproj` to confirm version pinning; reuse the same. No new package needed for this rule.
- **`HoneyDrunk.Kernel.Abstractions`** — required at *runtime* of the analyzer to reflect on `ClassificationAttribute`? No — the analyzer detects the attribute by its **fully-qualified type name** as a string match (`HoneyDrunk.Kernel.Abstractions.DataClassification.ClassificationAttribute`), avoiding a hard package reference. This is the standard pattern for analyzers that detect framework-defined attributes (the analyzer does not need to load the attribute type at compile time; the consuming project loads it). Do NOT add a `PackageReference` to `HoneyDrunk.Kernel.Abstractions` from the analyzer project.
- The analyzer-tests project needs `HoneyDrunk.Kernel.Abstractions` at runtime to construct test compilations that include realistic `[Classification]`-marked types. Add the reference there if not already present.

## Boundary Check
- [x] Analyzer rule lives in `HoneyDrunk.Standards.Analyzers` — the existing canonical home for Grid-wide analyzer rules (invariant 26). Routing rule "architecture, ADR, invariant" does NOT apply — this is code in the Standards repo, not documentation in the Architecture repo.
- [x] No reference from `HoneyDrunk.Standards.Analyzers` to `HoneyDrunk.Kernel.Abstractions`. Attribute detection by FQN string.
- [x] Pulse-side log scrubber, Audit-side redactor, and the Architecture-side catalog work each live in their own packets.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards.Analyzers` ships a new `DiagnosticAnalyzer` for unmarked classification on properties of records/classes in projects that reference `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions`
- [ ] The diagnostic has a stable `HD####` (or current prefix) ID, severity `Warning` at v1, a clear title/message/help-link pointing to the rule documentation
- [ ] The rule respects `Inherited = true` on `ClassificationAttribute` — inherited markers satisfy the rule
- [ ] `[Classification(DataClass.Public)]` on a property is a valid opt-out (no diagnostic)
- [ ] Tests in `HoneyDrunk.Standards.Tests` cover at minimum: unmarked → warning; marked any tier → no warning; out-of-scope project → no warning; inherited marker → no warning
- [ ] No `PackageReference` to `HoneyDrunk.Kernel.Abstractions` in the analyzer project (attribute detection by FQN string)
- [ ] `HoneyDrunk.Standards.Analyzers/README.md` documents the rule including the warning-to-error phase progression and the opt-out
- [ ] Every non-test `.csproj` in the Standards solution is at the new same minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[X.Y.0]` entry describing the new analyzer rule
- [ ] `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` has a per-package entry (real change)
- [ ] Other non-test packages in the Standards solution have NO per-package CHANGELOG entry (alignment bump only, invariant 12/27)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0049 D4 — Analyzer rule.** "`HoneyDrunk.Analyzers` (the standard analyzer package consumed via `Directory.Build.props`) ships a rule that flags **unmarked properties on types in `Restricted`-classified contexts** — specifically, properties on records persisted by `HoneyDrunk.Data` repositories or shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange`. Unmarked is an error; explicit `[Classification(DataClass.Public)]` is the way to opt out. This catches 'developer added a new field and forgot to classify it' at compile time."

(Note: ADR-0049 references "`HoneyDrunk.Analyzers`" as the package name; the existing Grid analyzer package is `HoneyDrunk.Standards.Analyzers`. Same artifact, same role; this packet uses the existing canonical name.)

**ADR-0049 D10 Phase 1 — Phased rollout.** "Author `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory` in `HoneyDrunk.Kernel.Abstractions`. Author the analyzer rule. Ship as part of `Kernel` v0.8.0. Existing fields are `[Classification(DataClass.Internal)]` by default (compatibility); the analyzer surfaces unclassified surface as warnings, not errors, for the first 30 days." This packet ships the analyzer in warning mode; packet 10 flips it to error after the 30-day window.

**ADR-0049 Alternatives Considered — naming-convention-based marking.** "Fragile under refactoring. Aliased types, records reshaped at boundaries, transitive payloads inside `Dictionary<string, object>` all defeat naming conventions. Not analyzer-checkable in a meaningful way. Attributes are reflection-discoverable, declarative, type-aware." The analyzer is the load-bearing reason for choosing attributes over conventions.

## Constraints
- **Severity is `Warning` at v1.** Do not ship the rule at `Error` severity. Packet 10 (Phase 4) flips it to error at the 30-day mark after the per-Node backfill packets (07, 08) land.
- **Attribute detection by FQN string, not type reference.** The analyzer must not take a `PackageReference` on `HoneyDrunk.Kernel.Abstractions` — that creates a circular-dependency risk and breaks the consume-with-`PrivateAssets: all` distribution model. The standard Roslyn pattern for this case is to match the attribute's fully-qualified type name as a string.
- **Detection scope is project-level coarse (PackageReference-based).** Over-fires on non-persisted types in `HoneyDrunk.Data`-referencing projects are acceptable at v1 — the developer adds `[Classification(DataClass.Public)]` to silence (one line). A more-precise call-graph variant is a follow-up, not this packet's scope.
- **Invariant 27 — All projects in a solution share one version.** Bump every non-test `.csproj` in `HoneyDrunk.Standards` to the same new minor version in one commit.
- **Invariant 12 — Per-package CHANGELOGs only for packages with real changes.** Only `HoneyDrunk.Standards.Analyzers` gets a per-package entry. Other solution packages are alignment bumps — no entries.
- **The analyzer ships alongside existing analyzer rules in the same project.** Do not create a new analyzer NuGet package for this rule. The Standards-analyzer package is the canonical Grid-wide analyzer distribution (invariant 26).

## Labels
`feature`, `tier-2`, `meta`, `adr-0049`, `wave-2`

## Agent Handoff

**Objective:** Ship the unmarked-classification Roslyn analyzer rule in `HoneyDrunk.Standards.Analyzers` at `Warning` severity, with tests, README, and a coordinated solution-version bump.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Mechanically catch unmarked fields on persisted records and audit-payload types at compile time, per ADR-0049 D4.
- Feature: ADR-0049 Data Classification rollout, Wave 2 (Phase 1 contract foundation).
- ADRs: ADR-0049 D4 (primary), ADR-0049 D10 (warning-to-error phase progression).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `ClassificationAttribute` and `PiiFieldAttribute` exist in `HoneyDrunk.Kernel.Abstractions` so the analyzer's FQN string match has a real target.

**Constraints:**
- Severity is `Warning` at v1; packet 10 flips to `Error` at the 30-day mark.
- Attribute detection by FQN string, not by package reference. No `PackageReference` to `HoneyDrunk.Kernel.Abstractions` from the analyzer project.
- Detection scope is project-level (any project referencing `HoneyDrunk.Data` or `HoneyDrunk.Audit.Abstractions` qualifies); over-fires are acceptable at v1.
- Bump every non-test `.csproj` in the Standards solution to the same new minor version in one commit (invariant 27).
- Per-package CHANGELOG entry on `HoneyDrunk.Standards.Analyzers` only.
- Ship the rule alongside existing rules in the same analyzer project — do not create a new NuGet package.

**Key Files:**
- `HoneyDrunk.Standards.Analyzers/` — new analyzer source files.
- `HoneyDrunk.Standards.Analyzers/CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Standards.Tests/` — new tests.
- Repo-level `CHANGELOG.md`.
- Every non-test `.csproj` in the solution for the version bump.

**Contracts:**
- New diagnostic ID `HD####` (next free in the existing sequence) — emitted on unmarked-property-on-persisted-record cases.
