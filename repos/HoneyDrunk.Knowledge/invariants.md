# HoneyDrunk.Knowledge — Invariants

Knowledge-specific invariants (supplements `constitution/invariants.md`).

1. **Knowledge.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Every retrieved chunk has source attribution.**
   No anonymous results. Every chunk traces back to source document, version, and ingestion timestamp.

3. **Knowledge sources are versioned.**
   When a document is re-ingested, previous versions are superseded. Retrieval reflects the current version.

4. **Ingestion is idempotent.**
   Re-ingesting the same source at the same version produces no duplicate chunks.

5. **Retrieval results include confidence scores.**
   Every result from `IRetrievalPipeline` includes a relevance score so consumers can threshold.

6. **GridContext is propagated through ingestion and retrieval.**
   CorrelationId flows from the triggering operation through to embedding generation and storage.

7. **Knowledge content never appears in Pulse telemetry.**
   Only metadata (source ID, chunk count, query latency, result count) is emitted. Content stays in the knowledge store.
