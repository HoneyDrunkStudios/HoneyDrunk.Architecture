# PR Review Rules

Rules for agents when reviewing pull requests.

## Review Checklist

### Boundary Compliance
- [ ] Changes are within the repo's stated responsibilities (`boundaries.md`)
- [ ] No new cross-Node dependencies introduced without ADR
- [ ] Abstractions packages remain dependency-free

### Contract Safety
- [ ] No breaking changes to public interfaces without version bump
- [ ] XML documentation on all new public APIs
- [ ] Return types are consistent with existing patterns

### Invariant Preservation
- [ ] No violation of `constitution/invariants.md`
- [ ] No violation of repo-specific `invariants.md`
- [ ] Secret values not exposed in logs, traces, or error messages

### Code Quality
- [ ] HoneyDrunk.Standards analyzers pass (no suppressions added)
- [ ] Primary constructors used where appropriate
- [ ] Nullable reference types respected (no `!` suppression without justification)
- [ ] New helper/mapper/validator/orchestration methods were checked against existing reusable methods before adding one-off logic
- [ ] Repeated logic is consolidated into cohesive shared methods, or intentional duplication is justified because behavior should diverge
- [ ] Tests added for new behavior
- [ ] CHANGELOG.md updated

### Context Propagation
- [ ] GridContext properly propagated across new code paths
- [ ] CorrelationId preserved in any new middleware or handlers
- [ ] New async boundaries maintain context flow

### Cost Governance (ADR-0052)
- [ ] **`cost-config`** (`block`) — edits to `business/context/cost-budgets.json` are production-config changes: hard cap ≥ soft cap; a removed hard cap pairs with `kill_switch: "none"`; anomaly multipliers in band (hour-over-hour `[1.5, 20.0]`, day-over-day `[1.2, 10.0]`); dev-overlay caps smaller than prod; and a justification in the PR description. Do not approve without operator sign-off. See ADR-0052 D2.
- [ ] **`cost-kill-switch-retry`** (`block`) — no code path catches `BudgetExceededException` and retries within the same billing window (sealed, non-transient, no-retry contract). Generic `catch (Exception)` around LLM calls and `Policy.Handle<Exception>()` against an LLM delegate are flagged unless they exclude the type; a single top-level loop handler that checkpoints to Audit and exits is allowed. See ADR-0052 D4 and invariant 105.

## Severity Levels

- **Block:** Invariant violation, security issue, breaking change without version bump
- **Request Changes:** Missing tests, missing docs, boundary concerns
- **Suggest:** Style improvements, naming suggestions, optional refactors


## ADR-0044 D3 Category Severity Mapping

The three severity levels above remain the canonical taxonomy. ADR-0044 D3 adds the twenty-category review rubric; this section maps each category onto `Block`, `Request Changes`, and `Suggest` so reviewers apply severity consistently.

### 1. Correctness and functional integrity
- **Block:** Behavior is unsafe or materially wrong; data/state corruption; broken idempotency for repeatable writes; accepted requirements cannot work.
- **Request Changes:** Edge cases, null/error states, timezone/culture issues, or packet acceptance criteria are missed but the core path is recoverable.
- **Suggest:** Clarify behavior, tighten naming, or add low-risk guardrails where correctness is otherwise sound.

### 2. Architectural integrity
- **Block:** Violates Node boundaries, dependency direction, or a binding ADR/invariant without a new ADR.
- **Request Changes:** Creates undocumented scope expansion, ambiguous ownership, or boundary drift that should be corrected before merge.
- **Suggest:** Add clarifying docs or follow-up packets for low-risk architecture questions.

### 3. Maintainability
- **Block:** Introduces unmaintainable control flow or hidden coupling that makes the system unsafe to evolve.
- **Request Changes:** Adds needless complexity, unclear structure, or debt that will block likely follow-up work.
- **Suggest:** Improve readability, naming, local organization, or comments where behavior is otherwise acceptable.

### 4. Reuse and ecosystem cohesion
- **Block:** Bypasses a required shared contract/policy surface or creates a competing source of truth.
- **Request Changes:** Adds avoidable duplicate implementations, divergent naming, or one-off helpers where shared behavior exists.
- **Suggest:** Consolidate or reference shared patterns in a safe follow-up when duplication is minor.

### 5. SOLID and design principles
- **Block:** Mixes responsibilities or abstractions so severely that correctness or boundary ownership is compromised.
- **Request Changes:** Broad interfaces, copy-paste policy logic, speculative abstractions, or avoidable responsibility leakage.
- **Suggest:** Small KISS/SOLID improvements that reduce future friction without changing the shipped contract.

### 6. Performance and scalability
- **Block:** Introduces unbounded work, hot-path model/API calls, or cost/latency risk likely to fail production constraints.
- **Request Changes:** Missing limits, batching, cancellation, sampling, or cost controls for plausible scale.
- **Suggest:** Minor optimization, measurement, or documentation improvements where scale risk is low.

### 7. Reliability and resilience
- **Block:** Failure mode can cause data loss, repeated side effects, outage amplification, or unrecoverable partial state.
- **Request Changes:** Missing retry/backoff, timeout, rollback, poison handling, or partial-failure behavior.
- **Suggest:** Add resilience notes or follow-up hardening for low-probability failures.

### 8. Observability and diagnostics
- **Block:** Removes or prevents required correlation, auditability, or production diagnosis for critical paths.
- **Request Changes:** Missing logs/metrics/traces/health checks for new behavior, or telemetry that is too noisy/sparse to operate.
- **Suggest:** Improve event names, dimensions, dashboard notes, or troubleshooting docs.

### 9. Security
- **Block:** Secret leakage, auth bypass, token/RBAC escalation, unsafe deserialization, or broadened tenant/data exposure.
- **Request Changes:** Missing permission checks, weak validation, incomplete secret handling, or unclear security boundary.
- **Suggest:** Defense-in-depth, documentation, or hardening improvements where no immediate exploit path exists.

### 10. Enterprise readiness
- **Block:** Breaks required audit, tenancy, compliance, retention, or operational control for enterprise-facing surfaces.
- **Request Changes:** Missing admin/audit hooks, data-classification notes, tenant isolation, or supportability requirements.
- **Suggest:** Improve enterprise documentation, runbooks, or future-readiness notes.

### 11. Testing quality
- **Block:** No meaningful verification for high-risk behavior, contract changes, or bug fixes where regressions are likely.
- **Request Changes:** Tests are missing, too shallow, skipped, flaky, or do not exercise acceptance criteria.
- **Suggest:** Add coverage for minor edge cases or improve test clarity where core behavior is already proven.

### 12. API and contract design
- **Block:** Breaking public contract without versioning/changelog/migration, or contract shape contradicts established Grid patterns.
- **Request Changes:** Missing XML docs, inconsistent return/error models, undeclared public surface, or weak compatibility story.
- **Suggest:** Naming, docs, overload shape, or ergonomics improvements that preserve compatibility.

### 13. Data and persistence integrity
- **Block:** Data loss/corruption risk, unsafe migration, broken ordering/deduplication, or non-idempotent persistence side effects.
- **Request Changes:** Missing rollback/backfill/versioning, weak consistency handling, or hidden ordering assumptions.
- **Suggest:** Clarify persistence docs, indexes, retention notes, or low-risk migration follow-ups.

### 14. Distributed systems concerns
- **Block:** Unsafe cross-service assumptions, message loss/duplication hazards, broken eventual consistency, or distributed deadlock risk.
- **Request Changes:** Missing idempotency, ordering, timeout, retry, poison-message, or compatibility handling across boundaries.
- **Suggest:** Add diagrams, sequence notes, or future canaries for low-risk distributed behavior.

### 15. CI/CD and delivery
- **Block:** Makes required gates unreliable, weakens branch protection, leaks secrets, or can deploy unsafe artifacts.
- **Request Changes:** Missing workflow permissions, artifact/replay evidence, changelog/version discipline, or advisory-vs-blocking clarity.
- **Suggest:** Improve job names, summaries, caching, or workflow documentation.

### 16. Developer experience (DX)
- **Block:** Breaks common development/build/test workflow or makes local verification impossible without undocumented secrets.
- **Request Changes:** Missing setup docs, confusing errors, poor templates, or friction that will cause repeated mistakes.
- **Suggest:** Improve examples, messages, docs, or small ergonomics.

### 17. Product and business alignment
- **Block:** Contradicts accepted PDR/charter direction, creates external promises the Grid cannot honor, or ships misaligned product behavior.
- **Request Changes:** Scope does not match product intent, pricing/tier/support implications are unstated, or user value is unclear.
- **Suggest:** Add positioning, rollout, or follow-up notes where alignment is mostly sound.

### 18. AI and agent-specific concerns
- **Block:** Unsafe autonomous behavior, missing circuit breaker for agent actions, lost provenance/authorship, prompt/data leakage, or non-idempotent replay.
- **Request Changes:** Missing `Authorship:` declaration, unclear agent handoff, weak context boundaries, or duplicate review/comment behavior.
- **Suggest:** Improve prompt clarity, evidence detail, or agent-readability where safety is intact.

### 19. Anti-entropy and long-term system health
- **Block:** Creates a new ungoverned pattern, permanent exception, or duplicate policy surface likely to fragment the Grid.
- **Request Changes:** Adds drift/debt without tracking, leaves stale docs/catalogs, or hides follow-up work needed for coherence.
- **Suggest:** Add cleanup packets, consolidation notes, or small doc syncs for low-risk entropy.

### 20. Human factors
- **Block:** Hides material risk from the human reviewer/operator or makes the PR impossible to safely review.
- **Request Changes:** PR lacks packet/authorship context, evidence, operational notes, or reviewer-facing explanation needed for a confident merge.
- **Suggest:** Improve summary, screenshots, examples, checklist clarity, or review ergonomics.
