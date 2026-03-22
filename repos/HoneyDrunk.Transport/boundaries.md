# HoneyDrunk.Transport — Boundaries

## What Transport Owns

- Message publishing and consumption abstractions
- Middleware pipeline (GridContext propagation → Telemetry → Logging → Handler)
- Immutable transport envelope with correlation/causation tracking
- Transactional outbox abstractions (`IOutboxStore`, `IOutboxDispatcher`)
- Transport-specific health contributors
- Provider implementations (Azure Service Bus, Storage Queue, InMemory)

## What Transport Does NOT Own

- **Message serialization format** — Applications choose serializers
- **Business logic** — Handlers contain business logic, not Transport
- **Database outbox storage** — `IOutboxStore` implementation belongs in HoneyDrunk.Data.Outbox
- **Context model** — GridContext definition belongs in Kernel
- **REST/HTTP** — HTTP-specific concerns belong in Web.Rest
- **Queue-based notifications** — Queue management for notifications belongs in Notify
