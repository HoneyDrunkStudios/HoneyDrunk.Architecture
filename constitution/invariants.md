# Grid Invariants

Rules that must never be violated across the HoneyDrunk Grid. Canary tests enforce these at build time. Architecture reviews enforce them at design time.

## Dependency Invariants

1. **Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.**
   Only `Microsoft.Extensions.*` abstractions are permitted.

2. **Runtime packages depend on Abstractions, never on other runtime packages at the same layer.**
   `HoneyDrunk.Transport` depends on `HoneyDrunk.Kernel.Abstractions`, not `HoneyDrunk.Kernel`.

3. **Provider packages depend on their parent Node's Abstractions, not the runtime package.**
   `HoneyDrunk.Vault.Providers.AzureKeyVault` → `HoneyDrunk.Vault` (which re-exports abstractions), never on internal Vault implementation details.

4. **No circular dependencies.** The dependency graph is a DAG. Kernel is always at the root.

## Context Invariants

5. **GridContext must be present in every scoped operation.**
   Every HTTP request, message handler, and background job must have a populated `IGridContext`.

6. **CorrelationId is never null or empty in a live GridContext.**
   It is generated at the entry point and propagated through all downstream calls.

7. **Context mappers are static and stateless.**
   `HttpContextMapper`, `MessagingContextMapper`, `JobContextMapper` — no instance state.

## Secrets & Trust Invariants

8. **Secret values never appear in logs, traces, exceptions, or telemetry.**
   Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

9. **Vault is the only source of secrets.**
   No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

10. **Auth tokens are validated, never issued.**
    HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider.

## Packaging Invariants

11. **One repo per Node (or tightly coupled Node family).**
    Each repo has its own solution, CI pipeline, and versioning.

12. **Semantic versioning with CHANGELOG.**
    Breaking changes bump major. New features bump minor. Fixes bump patch.

13. **All public APIs have XML documentation.**
    Enforced by HoneyDrunk.Standards analyzers.

## Testing Invariants

14. **Canary tests validate cross-Node boundaries.**
    Each Node that depends on another has a `.Canary` project verifying integration assumptions.

15. **Tests never depend on external services.**
    Use InMemory providers (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`) for isolation.

16. **No test code in runtime packages.**
    Tests live in dedicated `.Tests` or `.Canary` projects only.
