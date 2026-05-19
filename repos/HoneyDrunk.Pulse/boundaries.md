# HoneyDrunk.Pulse - Boundaries

## What Pulse Owns
- Sink interfaces (`ITraceSink`, `ILogSink`, `IMetricsSink`, `IAnalyticsSink`, `IErrorSink`)
- OpenTelemetry preconfigured pipelines with Grid context enrichment
- Multi-backend fan-out with per-sink failure isolation
- Pulse.Collector (OTLP HTTP + gRPC receiver) using Kernel canonical Pulse identity fallback
- Shared event contracts (`PulseIngested`, etc.)

## What Pulse Does NOT Own
- **Context model** - GridContext definition and canonical Node IDs belong in Kernel
- **Transport** - Message publishing for events belongs in Transport
- **Secret management** - Sink credentials come from Vault
