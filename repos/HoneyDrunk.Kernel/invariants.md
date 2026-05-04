# HoneyDrunk.Kernel — Invariants

Kernel-specific invariants (supplements `constitution/invariants.md`).

1. **Kernel.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **GridContext is always available in scoped operations.**
   `IGridContextAccessor.Context` is non-nullable after scope initialization.

3. **Context mappers are static and stateless.**
   `HttpContextMapper`, `MessagingContextMapper`, `JobContextMapper` have no instance state.

4. **AddHoneyDrunkNode() can only be called once.**
   The DI registration guard prevents duplicate registrations.

5. **CorrelationId is never empty.**
   `CorrelationId.NewId()` always produces a valid ULID. The default value is not valid.

6. **TenantId is always explicit in context.**
   `IGridContext.TenantId` and `IOperationContext.TenantId` are non-nullable `TenantId` values. Header-less internal Grid operations carry `TenantId.Internal`; malformed external tenant wire values are rejected at the boundary.

7. **Kernel exposes tenancy seams, not tenant policy.**
   Kernel owns `ITenantRateLimitPolicy`, `IBillingEventEmitter`, and no-op defaults so Nodes can compose tenancy consistently. Product Nodes own quotas, billing plans, enforcement, and commercial behavior.

8. **Baggage is append-only within a scope.**
   `IGridContext.AddBaggage()` adds entries. Entries cannot be removed once added.

9. **Lifecycle hooks execute in registration order.**
   `IStartupHook` instances run in the order they were registered in DI.
