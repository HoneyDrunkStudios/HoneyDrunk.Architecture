# HoneyDrunk.AI — Invariants

AI-specific invariants (supplements `constitution/invariants.md`).

1. **AI.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Every inference call emits Pulse telemetry.**
   Token counts, latency, model identifier, and cost estimate are required on every call. No silent inference.

3. **API keys are never hardcoded or passed as parameters.**
   All provider credentials are resolved through Vault at startup or on first use. Never in configuration files.

4. **Provider failures do not crash the caller.**
   Provider adapters must return structured error results, not throw unhandled exceptions. Circuit breaker patterns apply.

5. **Model identifiers are normalized.**
   Regardless of provider, model identifiers follow a canonical format so telemetry and routing are comparable.

6. **GridContext is propagated on every inference call.**
   CorrelationId and CausationId flow through to provider requests for end-to-end tracing.

7. **No provider-specific types leak through Abstractions.**
   Consumers of `HoneyDrunk.AI.Abstractions` never see OpenAI SDK types, Anthropic SDK types, etc.
