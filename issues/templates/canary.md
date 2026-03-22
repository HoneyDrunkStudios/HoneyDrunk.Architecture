---
name: Canary Investigation
type: canary
tier: 2
target_repo: "{repo}"
---

# Canary Failure: {Title}

## Failing Canary
**Repo:** `{HoneyDrunkStudios/RepoName}`  
**Test Project:** `{Repo}.Canary`  
**Test Name:** `{TestClassName}.{TestMethodName}`

## Invariant Violated
<!-- Reference the specific invariant from constitution/invariants.md -->
**Invariant #{number}:** {invariant text}

## Failure Details
<!-- Error message, stack trace, or assertion failure -->
```
{error output}
```

## Root Cause Analysis
<!-- What changed to cause this failure? Was it an upstream contract change, a regression, or a test issue? -->

## Proposed Fix
<!-- How to resolve the canary failure -->

### Option A: Fix Downstream
<!-- If the upstream change was correct, fix the canary/downstream code -->

### Option B: Revert Upstream
<!-- If the upstream change was wrong, revert it -->

## Acceptance Criteria
- [ ] Root cause identified
- [ ] Fix implemented
- [ ] Canary test passing
- [ ] No other canary tests broken by the fix

## Labels
`canary`, `tier-2`, `boundary-violation`
