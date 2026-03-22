# HoneyDrunk.Transport — Invariants

1. **Transport depends only on Kernel.Abstractions, not full Kernel.**
2. **Envelopes are immutable.** Use `WithHeaders()` / `WithGridContext()` for modified copies.
3. **Always use EnvelopeFactory to create envelopes.** Never construct `TransportEnvelope` directly.
4. **Middleware order matters.** GridContextPropagation → Telemetry → Logging → Handler.
5. **Transport implementations must implement `IAsyncDisposable`.** Thread-safe disposal with `Interlocked.Exchange`.
6. **Grid context fields are always mapped.** NodeId, StudioId, Environment must be propagated to broker metadata.
