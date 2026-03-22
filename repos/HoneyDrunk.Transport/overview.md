# HoneyDrunk.Transport — Overview

**Sector:** Core  
**Version:** 0.4.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Transport`

## Purpose

Transport-agnostic messaging with a middleware pipeline, immutable envelopes, and transactional outbox support. Provides unified `ITransportPublisher` / `ITransportConsumer` abstractions over multiple brokers.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Transport` | Runtime | Core abstractions, middleware pipeline, envelope contracts |
| `HoneyDrunk.Transport.AzureServiceBus` | Provider | Azure Service Bus transport |
| `HoneyDrunk.Transport.StorageQueue` | Provider | Azure Storage Queue transport |
| `HoneyDrunk.Transport.InMemory` | Testing | In-memory broker for tests |

## Key Interfaces

- `ITransportPublisher` / `ITransportConsumer` — Publish/subscribe contracts
- `ITransportEnvelope` — Immutable message wrapper with Grid context
- `IMessageMiddleware` — Onion-style middleware pipeline
- `IMessageHandler<T>` — Typed message handler
- `IOutboxStore` / `IOutboxDispatcher` — Transactional outbox pattern
- `ITransportHealthContributor` — Health checks per transport
