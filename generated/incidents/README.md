# Incident Log

Post-mortems and canary boundary failure reports. Each incident documents what broke, what was learned, and what was changed so the Grid doesn't repeat the same failure.

## When to write an incident report

- A canary test reveals a cross-Node boundary violation
- A production bug is traced to an invariant being violated
- A Grid-wide outage or degradation occurs
- An agent execution produces an unexpected result that reveals a design gap

**You do not need a production outage.** A canary failure caught in CI is an incident. Write the report — it is cheaper to document near-misses than to repeat them.

## File naming

```
{YYYY-MM-DD}-{short-slug}.md
```

Examples:
- `2026-04-15-auth-canary-secret-pinning.md`
- `2026-05-01-vault-rotation-event-grid-miss.md`
- `2026-05-12-agent-context-null-in-background-job.md`

## Template

See [_template.md](_template.md) for the standard format.

## Index

| Date | Slug | Severity | Nodes | Status |
|------|------|----------|-------|--------|
| — | — | — | — | — |

*(Add entries here as incidents are filed.)*

---

## Severity levels

| Level | Meaning |
|-------|---------|
| **P0** | Grid-wide production outage or data loss |
| **P1** | Single-Node production degradation, user-facing impact |
| **P2** | Canary failure caught in CI, no production impact |
| **P3** | Design gap or near-miss discovered in review |
