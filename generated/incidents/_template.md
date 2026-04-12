# Incident: {Short Title}

**Date:** {YYYY-MM-DD}
**Severity:** P0 / P1 / P2 / P3
**Nodes affected:** {e.g., HoneyDrunk.Auth, HoneyDrunk.Vault}
**Detected by:** Canary test / CI / Production alert / Code review
**Status:** Open / Resolved / Monitoring

---

## What Happened

*One paragraph. What broke, when, and what was the user/system impact (if any).*

---

## Root Cause

*One paragraph. What invariant was violated, what assumption was wrong, or what design gap was exposed.*

```
Example:
Invariant 21 (no secret version pinning) was violated in HoneyDrunk.Auth.
The Azure Key Vault URI was being read with an explicit version parameter,
which meant the Event Grid invalidation event (ADR-0006) did not propagate
the rotated value. The Node continued to use the old secret for ~4 hours
until a restart forced a fresh resolution.
```

---

## Timeline

| Time | Event |
|------|-------|
| {HH:MM UTC} | {What happened} |
| {HH:MM UTC} | {Detection / escalation} |
| {HH:MM UTC} | {Fix deployed / canary restored} |

---

## What Was Changed

*List the concrete changes made:*

- [ ] Code change: {PR link or description}
- [ ] Canary test added: {what it checks}
- [ ] Invariant updated or added: {invariant number and text}
- [ ] ADR updated: {which ADR}
- [ ] Documentation updated: {which file}

---

## What We Learned

*One to three bullet points. Focus on what wasn't obvious before this incident.*

- 
- 

---

## Follow-up Work

*Any issue packets or ADRs that should be filed as a result of this incident.*

- [ ] {Description} — target: {repo}
- [ ] {Description} — target: {repo}
