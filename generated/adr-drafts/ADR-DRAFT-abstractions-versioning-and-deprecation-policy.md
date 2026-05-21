# ADR-DRAFT: Abstractions Versioning and Deprecation Policy

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid's coupling rule is **Abstractions-first**: every stand-up ADR from ADR-0016 (AI) through ADR-0031 (Audit) pins consumers to `*.Abstractions` packages and forbids reaching across into default backings. This rule only earns its keep if the Abstractions packages have a clear and predictable evolution story. Today they do not.

Concrete pressure points already on the board:

- The **Kernel Adoption Alignment** initiative (11/11 closed, in exit review) was the first ABI cascade. It was triaged ad-hoc as an "alignment initiative" because there was no policy. The next one will be the same unless this is decided.
- **ADR-0010 (Accepted)** added `IModelRouter`, `IRoutingPolicy`, and `ModelCapabilityDeclaration` to `HoneyDrunk.AI.Abstractions` and shipped them as Phase 1. Phase 2 already anticipates additions; the rules for "what additions are safe" are implicit.
- **ADR-0026** promoted `IGridContext.TenantId` from `string?` to `TenantId?` — a strict-typed breaking change to Kernel.Abstractions. It shipped as part of a coordinated cascade with no recorded deprecation window.
- **ADR-0027 D2** carves out private revenue Nodes (Notify.Cloud); revenue Nodes depending on public Abstractions need a stronger compatibility promise than internal cascades.
- **ADR-0034 (Proposed, NuGet)** publishes Abstractions packages to nuget.org. The moment an external consumer takes a dependency on `HoneyDrunk.AI.Abstractions 1.0.0`, the rules below must already be in writing.

This ADR is the policy. It governs version-number semantics, what changes are allowed at each level, the deprecation window, and the procedure for landing a breaking change.

## Decision

### D1 — Strict SemVer on all public Abstractions packages

`HoneyDrunk.<Node>.Abstractions` packages follow strict SemVer 2.0.0 with the interpretation below. The version number is not a marketing surface and is not aligned with the Node's calendar version; an Abstractions package may be at 1.4.2 while its default backing is at 0.6.0 and vice versa.

- **Major (X.0.0)** — any change to a frozen interface, record, or enum that a downstream compiled binary could observe as a break. Includes: removing a member, changing a signature, narrowing a return type, widening a parameter type beyond the previous accepted set, renaming, changing an enum's underlying type, reordering record positional parameters, adding a required interface member.
- **Minor (x.Y.0)** — additive only. New interface (separate file), new record, new enum value at the **end** of the list, new optional method *on a new interface* (never on an existing one — see D3). New extension method.
- **Patch (x.y.Z)** — documentation, XML doc fixes, package metadata, no IL change.

Pre-1.0 (`0.Y.Z`) versions are explicitly considered unstable; the minor/patch rules apply to `0.Y` cascades but no compatibility promise is made. **Every Abstractions package must reach 1.0.0 before its owning Node is declared GA.** Pre-1.0 status is the explicit signal "this contract is still being shaken out."

### D2 — Source vs binary compatibility

This policy guarantees **binary compatibility** at minor and patch versions, and aspires to source compatibility. Binary is the stronger and more testable guarantee; source is best-effort.

A minor-version bump must produce a package against which a binary compiled at the prior minor version continues to load and execute without `MissingMethodException`, `TypeLoadException`, or behavior change. ADR-0016's contract-shape canary is the test surface; canaries are extended per Node to cover this guarantee.

### D3 — Interface evolution rule

Adding a member to an **existing public interface** is a breaking change in .NET unless every member added is a **default-interface-member implementation**. The Grid's policy:

- **No default-interface-member additions.** The TFM matrix includes targets where DIM is unsupported (legacy .NET Standard consumers, AOT scenarios). DIM is a maintenance and discovery hazard even where supported.
- **New behavior on an existing surface lands on a new interface.** Pattern: `IModelRouter` v1 stays frozen; v2 capabilities go on `IModelRouter2` (or a differently-named, intention-revealing successor like `IModelRouterWithCostFloors`). Consumers opt in by taking the new dependency.
- The original interface gets `[Obsolete]` with a `DiagnosticId` only when the successor has shipped at the same major version and the **deprecation window** (D6) has elapsed. Until then it stays first-class.

### D4 — Record and DTO evolution

C# records compiled as positional types are brittle: adding a positional parameter is a binary break, reordering is a runtime-and-binary break. Grid policy:

- **All public records use property initializers (`init`) with named members, not positional syntax.** This makes addition non-breaking at the call site (`new Foo { A = 1, B = 2 }` continues to compile when `C` is added).
- **New members on a record are non-required.** Required members (`required` modifier or non-nullable reference types with no default) are part of the v1 surface and additions force a major.
- **Enums are extensible by default unless explicitly closed.** Enum values are documented as additive at minor versions; consumers `switch` exhaustively at their own risk and must include a default arm. An enum that is **not** extensible is annotated with an XML doc tag (`<closed/>`) and a `Roslyn` analyzer warning on switch exhaustiveness flips on.

### D5 — Pre-release channel

Breaking changes go through a **pre-release** channel before stable:

- New major versions ship to nuget.org as `X.0.0-preview.N` first (and to the Azure Artifacts pre-release feed per ADR-0034 D1 simultaneously).
- A `-preview` release is in market for **a minimum of 14 calendar days** with at least one internal Grid consumer pinned to it. The consumer's canary suite must pass against the preview before stable lands.
- `-rc.N` is the final pre-stable label and must be in market for at least 7 calendar days.
- No version skips: `1.0.0 → 2.0.0-preview.1 → 2.0.0-preview.2 → 2.0.0-rc.1 → 2.0.0`. Never `1.0.0 → 2.0.0` direct.

### D6 — Deprecation window

When a member is to be removed at the next major:

- At least one minor release between deprecation and removal must carry the `[Obsolete(message, error: false)]` attribute with a `DiagnosticId` and a `UrlFormat` pointing to a migration doc in the Node's repo.
- The migration doc names the replacement and shows a before/after snippet.
- The deprecation window is **a minimum of 60 calendar days** between the first minor that marks the member obsolete and the major that removes it.
- For pre-1.0 Abstractions, the window collapses to "next minor"; the 60-day floor is a 1.0+ guarantee.

### D7 — Coordinated cascade procedure

When a major-version bump on a Kernel-level Abstractions package will cascade through dependent Nodes (the Kernel Adoption Alignment pattern), the cascade is scoped as a named **initiative** under the ADR-0008 D10 slug convention (`adr-NNNN-<kebab>`), not as ad-hoc packets. The initiative file records:

- The bumping Node and its version delta (`Kernel.Abstractions 1.x → 2.0.0`).
- Every downstream Node and the version it must move to.
- The order in which downstream Nodes upgrade (topological per `catalogs/relationships.json`).
- The freeze/no-freeze status of `main` during the cascade.
- The pre-release window dates (D5).

This becomes the second instance of the Kernel Adoption Alignment pattern with explicit shape rather than retroactive triage.

### D8 — Private packages get a different rule

`HoneyDrunk.Notify.Cloud.*` and any future revenue Node (ADR-0027 D2) are not bound by D1–D6. Private packages may break consumers at minor versions because the consumer set is the Studio itself plus a known small population of paying tenants under contract. The trade-off is recorded explicitly: private packages buy velocity by giving up the public ABI promise. **Public Abstractions transitively consumed by a private package are still bound by this ADR** — Notify.Cloud cannot force a Kernel.Abstractions break.

### D9 — Enforcement

Three CI gates land in `HoneyDrunk.Actions`:

- **`Microsoft.CodeAnalysis.PublicApiAnalyzers`** is enabled on every public package. `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` are tracked in-repo; PRs that touch the public surface must update `Unshipped.txt`, and CI fails if the file is stale.
- **API-diff job** in the release workflow: compares the post-build `Unshipped.txt` to the previous-version package on nuget.org and asserts the diff matches the declared bump (additive-only for minor, no changes for patch). Implemented as a new reusable workflow `job-api-diff.yml`.
- **`[Obsolete]` audit job**: any `[Obsolete]` member without a `DiagnosticId` and a `UrlFormat` fails CI.

### D10 — Relationship to ADR-0034

This ADR governs version semantics. ADR-0034 governs distribution. The two land together; neither is useful alone, and `catalogs/package-feeds.json` (ADR-0034 D8) is the authority for which feeds these rules apply to.

## Consequences

### Affected Nodes

- **Every public Node** — gains `PublicAPI.{Shipped,Unshipped}.txt`, the analyzer reference, and a one-time baseline commit at current published version.
- **HoneyDrunk.Actions** — new `job-api-diff.yml` reusable workflow; consumer release workflows call it before publish.
- **HoneyDrunk.Architecture** — initiative slug convention (ADR-0008 D10) gains the cascade variant; an example template lives at `initiatives/templates/abstractions-cascade.md`.
- **Kernel.Abstractions** — currently at the version that absorbed ADR-0026's `TenantId` strict-typing. That bump is retroactively declared the **1.0.0 baseline** for the policy; pre-baseline history is grandfathered.

### Invariants

Adds three:

- **Invariant: every public Abstractions package follows strict SemVer per D1.** Calendar versions, marketing versions, and Node-aligned versions are forbidden.
- **Invariant: no default-interface-member additions on shipped public interfaces.** Successors land on new interfaces.
- **Invariant: a major-version cascade is an initiative, not a loose set of packets.** Procedure D7 is mandatory; ad-hoc cross-Node ABI changes are forbidden.

### Operational Consequences

- The `PublicAPI.Unshipped.txt` workflow adds one file to most PRs that touch contracts. This is a known cost of the policy; the analyzer is the only way to make API changes legible at review time.
- The 14-day preview floor (D5) and 60-day deprecation window (D6) slow individual breaking changes by ~75 days end-to-end. This is intentional; an SLA shorter than that is indistinguishable from no SLA for external consumers.
- Pre-1.0 Abstractions (currently every Node except the post-baseline Kernel) operate outside the window guarantee until they reach 1.0.0. The 1.0.0 declaration is now load-bearing and should be made deliberately, not by accident.
- Private revenue Nodes (ADR-0027 D2) lose the public-ABI promise. Their internal canary and integration-test coverage must be correspondingly stronger; recorded as a follow-up for ADR-0027.

### Follow-up Work

- Add `Microsoft.CodeAnalysis.PublicApiAnalyzers` to every public Node's `Directory.Build.props`; one-time baseline commit.
- Author `job-api-diff.yml` in HoneyDrunk.Actions.
- Author `initiatives/templates/abstractions-cascade.md`.
- Declare Kernel.Abstractions 1.0.0 baseline in a retroactive note; tag the corresponding release.
- Move each Node's Abstractions package to 1.0.0 only on deliberate review; do not bulk-bump.

## Alternatives Considered

### Calendar versioning (YYYY.MM.N)

Rejected. CalVer is incompatible with SemVer's "breaking-change signal in the version number" guarantee, which is the entire point of pinning external consumers. A calendar version tells the consumer **when** the package was built but nothing about **whether** it broke them.

### Lockstep versioning across all Grid packages

Rejected. Every Node would have to bump major when any one of them did, producing a stream of empty majors and obscuring real breakage signals. Independent SemVer per package is the standard answer for a polyrepo Grid.

### Allow default-interface-member additions at minor versions

Rejected. DIM is unsupported on AOT and on some target frameworks the Grid still emits (`netstandard2.0` for older consumers, possible NativeAOT for future edge bits per ADR-0029). Even where supported, DIM additions surprise consumers reading interface definitions and complicate the canary surface. The new-interface rule (D3) is more verbose at the source level and unambiguously safer at the binary level.

### Skip pre-release windows for "obvious" changes

Rejected. The 14/7 day floors exist so external consumers have a deterministic upgrade calendar, not so we can prove changes are safe. "Obvious" is the wrong axis; "in market for long enough to be observable" is.

### Defer the policy until a real external consumer files a compatibility bug

Rejected. The first such bug is also the first time the policy is litigated under pressure. Cheaper to decide now and roll out into a quiet baseline than to retrofit under deadline.
