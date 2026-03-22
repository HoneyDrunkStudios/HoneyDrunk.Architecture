# HoneyDrunk.Kernel — Active Work

**Last Updated:** 2026-03-22

## Current

- v0.4.0 is stable and released
- All downstream Nodes aligned except Notify and Pulse (in progress)

## Recent Changes (v0.4.0)

- `IGridContext.AddBaggage()` replaces `WithBaggage()` (mutates in-place, void return)
- `IGridContext.BeginScope()` removed
- `IGridContextAccessor` now read-only non-nullable property
- `IGridContextFactory.CreateRoot()` removed — only `CreateChild()`
- Context mappers are now static
- DI registration guard prevents duplicate `AddHoneyDrunkNode()` calls

## Upcoming

- No breaking changes planned for v0.5.0
- Evaluating: WebSocket context propagation support
- Evaluating: gRPC context mapper
