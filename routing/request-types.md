# Request Types

How to classify incoming work requests for routing purposes.

## Type Definitions

### `architecture-decision`
A design question or proposal that affects contracts, invariants, or cross-repo boundaries.
- **Tier:** 3 (Architecture Review)
- **Starts in:** This repo (ADR draft)
- **Signals:** "should we", "what if we changed", "new abstraction", "breaking change", "new Node"

### `repo-feature`
A feature or enhancement scoped to a single repo.
- **Tier:** 2 (Plan-Then-Execute)
- **Starts in:** Target repo
- **Signals:** "add support for", "implement", "new provider", "new middleware"

### `cross-repo-change`
A change that requires coordinated modifications across multiple repos.
- **Tier:** 2 or 3 depending on whether contracts change
- **Starts in:** This repo (issue packets per repo)
- **Signals:** "affects Kernel and Transport", "version bump across", "rename across"

### `bug-fix`
A defect in a specific repo.
- **Tier:** 1 or 2 depending on scope
- **Starts in:** Target repo
- **Signals:** "broken", "failing", "regression", "exception"

### `site-sync`
Content changes needed on the Studios website to reflect architecture changes.
- **Tier:** 1 (Auto-Execute)
- **Starts in:** This repo (site-sync packet)
- **Signals:** "update docs", "new version released", "new Node announced"

### `ci-change`
Changes to GitHub Actions workflows or CI infrastructure.
- **Tier:** 2 (Plan-Then-Execute)
- **Starts in:** HoneyDrunk.Actions
- **Signals:** "workflow", "CI", "pipeline", "build step"

### `canary`
A canary test failure indicating a cross-Node boundary violation.
- **Tier:** 2 (Plan-Then-Execute)
- **Starts in:** This repo (investigation)
- **Signals:** "canary failed", "boundary violation", "invariant broken"

### `dependency-upgrade`
Upgrading a shared dependency (e.g., Kernel version) across consuming Nodes.
- **Tier:** 2 (Plan-Then-Execute)
- **Starts in:** This repo (coordination)
- **Signals:** "upgrade Kernel to", "new version of", "dependency update"
