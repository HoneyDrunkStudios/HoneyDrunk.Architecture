# Handoff — Kernel Adoption Alignment

## Purpose
Use this when moving from Kernel foundation work into downstream repo execution.

## Upstream Expectations
Packet 01 must publish/merge a Kernel package version that provides:
- Canonical `WellKnownNodes` values for current Grid Nodes (`honeydrunk-*`).
- An Abstractions-visible context bootstrap/factory seam so libraries like Transport do not need concrete `GridContext.Initialize()`.
- Passing Kernel build/tests and updated changelogs/version metadata.

## Downstream Execution Rule
Each downstream repo branches from updated `main`, updates only its own package references/code/tests/changelogs, and validates with repo-local restore/build/test. Do not merge any repo until Oleg explicitly verifies.

## Critical Invariants
- Every HTTP request, message handler, and background job must have populated Grid context: correlation, node, studio, environment, and tenant (`TenantId.Internal` for internal/system work).
- Secret values never appear in logs/traces/exceptions. Vault is the only source of secrets; deploy-time bootstrap settings are identifiers/endpoints, not committed secrets.
- Abstractions packages stay dependency-light; avoid full runtime package references when Abstractions contracts are sufficient.
- All non-test projects in a solution move version together when a bump is warranted.
