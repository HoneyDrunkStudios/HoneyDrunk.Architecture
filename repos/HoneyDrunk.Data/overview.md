# HoneyDrunk.Data — Overview

**Sector:** Core  
**Version:** 0.3.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Data`

## Purpose

Persistence conventions, repository patterns, tenant-aware data access, and transactional outbox. Provides EF Core and SQL Server implementations.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Data.Abstractions` | Abstractions | Repository, UoW, tenant contracts |
| `HoneyDrunk.Data` | Runtime | Provider-neutral orchestration |
| `HoneyDrunk.Data.EntityFramework` | Provider | EF Core repository + unit of work |
| `HoneyDrunk.Data.SqlServer` | Provider | SQL Server specialization |
| `HoneyDrunk.Data.Outbox` | Runtime | Outbox abstractions |
| `HoneyDrunk.Data.Outbox.Dispatcher` | Runtime | Background outbox dispatcher |
