# HoneyDrunk.Pulse — Overview

**Sector:** Ops  
**Version:** 0.3.0
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Pulse`

## Purpose

Multi-backend telemetry pipeline with OTel integration. Pulse provides sink interfaces, OpenTelemetry preconfigured pipelines, and a deployable OTLP collector.

As of v0.3.0, Pulse.Collector uses Kernel canonical `WellKnownNodes.Ops.Pulse` identity fallback while preserving deploy-time `HONEYDRUNK_NODE_ID` overrides. Loki, Mimir, and Tempo share internal HTTP OTLP sink helpers instead of duplicating public helper APIs.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Pulse.Contracts` | Abstractions | Shared event models (multi-target) |
| `HoneyDrunk.Telemetry.Abstractions` | Abstractions | Sink interfaces |
| `HoneyDrunk.Telemetry.OpenTelemetry` | Runtime | OTel pipeline integration |
| `HoneyDrunk.Telemetry.Sink.*` | Provider | Loki, Tempo, Mimir, PostHog, Sentry, AzureMonitor |
