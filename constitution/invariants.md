# Grid Invariants

Rules that must never be violated across the HoneyDrunk Grid. Canary tests enforce these at build time. Architecture reviews enforce them at design time.

## Dependency Invariants

1. **Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.**
   Only `Microsoft.Extensions.*` abstractions are permitted.

2. **Runtime packages depend on Abstractions, never on other runtime packages at the same layer.**
   `HoneyDrunk.Transport` depends on `HoneyDrunk.Kernel.Abstractions`, not `HoneyDrunk.Kernel`.

3. **Provider packages depend on their parent Node's contracts, not internal implementation details.**
   When a Node splits contracts into a separate package (e.g. `HoneyDrunk.Kernel.Abstractions`),
   providers reference that package. When a Node bundles contracts into its main package
   (e.g. `HoneyDrunk.Vault`), providers reference the main package. In either case, providers
   must only consume exported interfaces — never internal types, caches, or resilience plumbing.

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

## Infrastructure & Configuration Invariants

17. **One Key Vault per deployable Node per environment.**
    Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

18. **Vault URIs and App Configuration endpoints reach Nodes via environment variables.**
    `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

19. **Service names in Azure resource naming must be ≤ 13 characters.**
    Required to fit within Azure's 24-character Key Vault name limit (`kv-hd-{service}-{env}`). See ADR-0005.

20. **No secret may exceed its tier's rotation SLA without an active exception.**
    Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. See ADR-0006.

21. **Applications must never pin to a specific secret version.**
    All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

22. **Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.**
    Required for rotation SLA monitoring, unauthorized access alerting, and audit. See ADR-0006.

## Work Tracking Invariants

23. **Every tracked work item has a GitHub Issue in its target repo.**
    No work tracked exclusively in packet files, chat logs, or external tools. Issues live where the code lives. See ADR-0008.

24. **Issue packets are immutable specifications.**
    State lives on the org Project board, never in the packet file. If requirements change materially, write a new packet rather than editing the old one. See ADR-0008.

25. **Dispatch plans are initiative narratives, not live state.**
    The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records. See ADR-0008.
