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
- [ ] Tests added for new behavior
- [ ] CHANGELOG.md updated

### Context Propagation
- [ ] GridContext properly propagated across new code paths
- [ ] CorrelationId preserved in any new middleware or handlers
- [ ] New async boundaries maintain context flow

## Severity Levels

- **Block:** Invariant violation, security issue, breaking change without version bump
- **Request Changes:** Missing tests, missing docs, boundary concerns
- **Suggest:** Style improvements, naming suggestions, optional refactors
