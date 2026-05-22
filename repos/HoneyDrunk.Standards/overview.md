# HoneyDrunk.Standards — Overview

**Sector:** Meta
**Version:** TBD
**Framework:** .NET (Roslyn analyzers + MSBuild build assets)
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Standards`
**Status:** Live — library-only, no deployable, no vault

## Purpose

HoneyDrunk.Standards is the Grid's shared code-quality and build-tooling repo. It is
the single home for the StyleCop + EditorConfig analyzer set referenced by every .NET
project in the Grid, the canonical solution-version conventions, and the shared
test-stack build assets committed by ADR-0047:

- The StyleCop + EditorConfig analyzer package referenced on every .NET project with
  `PrivateAssets: all` (invariant 26).
- The shared test-stack `Directory.Build.props` fragment — xUnit (v2.x) + NSubstitute +
  AwesomeAssertions + coverlet — consumed by `*.Tests.*` projects Grid-wide (ADR-0047 D2).
- The per-Node-tier `coverlet.runsettings` coverage-threshold templates (ADR-0047 D3).
- Build-time analyzer rules that enforce constitution invariants — e.g. the rule that
  fails any test project containing `Thread.Sleep` (invariant 51).

Standards contains no runtime behavior, ships no service, and holds no secrets. Its
packages are consumed at compile time only.

## References

- [ADR-0047: Testing Patterns and Tooling](../../adrs/ADR-0047-testing-patterns-and-tooling.md)
- `constitution/invariants.md` — invariants 26 (analyzers on every project), 27 (solution
  versioning), 51 (no `Thread.Sleep` in tests), 58 (Standards is the analyzer home).
