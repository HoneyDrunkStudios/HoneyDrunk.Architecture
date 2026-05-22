# HoneyDrunk.Standards — Boundaries

## What Standards Owns

- The Grid-wide StyleCop + EditorConfig analyzer set (invariant 26).
- The shared test-stack `Directory.Build.props` fragment — xUnit v2.x + NSubstitute +
  AwesomeAssertions + coverlet (ADR-0047 D2).
- The per-Node-tier `coverlet.runsettings` coverage-threshold templates (ADR-0047 D3).
- Build-time analyzer rules that enforce constitution invariants (e.g. the no-`Thread.Sleep`
  rule for test projects, invariant 51).
- Canonical, copy-once build conventions consumed at compile time by every Node.

## What Standards Does NOT Own

- Runtime behavior, services, or deployables — Standards is library/tooling-only.
- Secrets or configuration values — Standards has no vault and no runtime config.
- CI workflow definitions — reusable GitHub Actions workflows live in `HoneyDrunk.Actions`
  per ADR-0012. Standards ships the build assets the workflows invoke (props fragments,
  runsettings, analyzers); it does not ship the workflows.
- Per-Node adoption of its build assets — each Node opts in by referencing the analyzers
  and importing the shared fragment. Standards publishes the definitions; it does not edit
  consumer repos.
- Runtime contracts — Standards exposes no public interfaces, so it has no
  `catalogs/contracts.json` entry.

## Status

Live. ADR-0047 adds the test-stack props fragment, the coverage-threshold templates, and
the `Thread.Sleep` analyzer rule; implementation details are deferred to the ADR-0047
initiative packets (`adr-0047-testing-patterns-and-tooling`).
