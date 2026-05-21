# HoneyDrunk.Auth — Overview

**Sector:** Core  
**Version:** 0.5.0
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Auth`

## Purpose

JWT Bearer token validation and policy-based authorization with Vault-backed signing key management. Auth validates trust and enforces access — it is not an identity provider. As of v0.5.0, Auth emits durable token-validation and authorization audit events through `HoneyDrunk.Audit.Abstractions` when a host composes an `IAuditLog` backing.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Auth.Abstractions` | Abstractions | Token validation, policy evaluation contracts |
| `HoneyDrunk.Auth` | Runtime | JWT validation, signing key management, policy evaluation |
| `HoneyDrunk.Auth.AspNetCore` | Hosting | ASP.NET Core middleware integration |
