# HoneyDrunk.Data — Invariants

1. **Repository never exposes `IQueryable` to consumers.** Queries are encapsulated.
2. **Unit of work coordinates `SaveChangesAsync` across repositories.**
3. **Outbox messages are saved within the same transaction as business data.**
4. **Outbox dispatcher uses lease-based concurrency.** No double-dispatch.
5. **Correlation tagging is automatic.** SQL commands include CorrelationId via EF interceptors.
