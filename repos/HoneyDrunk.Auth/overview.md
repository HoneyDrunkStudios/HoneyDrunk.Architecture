# HoneyDrunk.Auth — Overview

**Sector:** Core  
**Version:** 0.2.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Auth`

## Purpose

JWT Bearer token validation and policy-based authorization with Vault-backed signing key management. Auth validates trust and enforces access — it is not an identity provider.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Auth.Abstractions` | Abstractions | Token validation, policy evaluation contracts |
| `HoneyDrunk.Auth` | Runtime | JWT validation, signing key management, policy evaluation |
| `HoneyDrunk.Auth.AspNetCore` | Hosting | ASP.NET Core middleware integration |
