# HoneyDrunk.Web.Rest — Overview

**Sector:** Core  
**Version:** 0.2.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Web.Rest`

## Purpose

Standardized REST API contracts — response envelopes, correlation propagation, exception mapping, pagination, and JSON conventions. Every HTTP response speaks the same language.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Web.Rest.Abstractions` | Abstractions | `ApiResult<T>`, pagination, validation models |
| `HoneyDrunk.Web.Rest.AspNetCore` | Hosting | Exception mapping middleware, correlation, JSON conventions |
