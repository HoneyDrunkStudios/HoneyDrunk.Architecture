# HoneyDrunk.Pulse — Overview

**Sector:** Ops  
**Version:** 0.1.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Pulse`

## Purpose

Multi-backend telemetry pipeline with OTel integration. Pulse provides sink interfaces, OpenTelemetry preconfigured pipelines, and a deployable OTLP collector.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Pulse.Contracts` | Abstractions | Shared event models (multi-target) |
| `HoneyDrunk.Telemetry.Abstractions` | Abstractions | Sink interfaces |
| `HoneyDrunk.Telemetry.OpenTelemetry` | Runtime | OTel pipeline integration |
| `HoneyDrunk.Telemetry.Sink.*` | Provider | Loki, Tempo, Mimir, PostHog, Sentry, AzureMonitor |
