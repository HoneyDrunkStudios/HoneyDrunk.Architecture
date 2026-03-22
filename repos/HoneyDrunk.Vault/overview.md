# HoneyDrunk.Vault — Overview

**Sector:** Core  
**Version:** 0.2.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Vault`

## Purpose

The Grid's canonical source of secrets and configuration. Other Nodes consume it via `ISecretStore` and `IConfigProvider` — never provider SDKs directly.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Vault` | Runtime | Core client, orchestrator, caching, resilience |
| `HoneyDrunk.Vault.Providers.AzureKeyVault` | Provider | Azure Key Vault |
| `HoneyDrunk.Vault.Providers.Aws` | Provider | AWS Secrets Manager |
| `HoneyDrunk.Vault.Providers.File` | Provider | File-based (dev) |
| `HoneyDrunk.Vault.Providers.Configuration` | Provider | IConfiguration bridge |
| `HoneyDrunk.Vault.Providers.InMemory` | Testing | In-memory store |

## Key Interfaces

- `ISecretStore` — Primary secret access (cross-Node consumption)
- `IConfigProvider` — Typed configuration with defaults
- `ISecretProvider` — Backend-specific implementations (internal)
- `SecretIdentifier` — Name + optional version
- `SecretValue` — Identifier + value + version
- `VaultResult<T>` — Result pattern for Try* methods
