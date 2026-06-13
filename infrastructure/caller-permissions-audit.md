# Caller Workflow Permissions Audit

**Date:** 2026-05-26
**ADR:** ADR-0012 Grid CI/CD Control Plane
**Invariant:** 39 — caller workflows declare a permissions block that is a superset of reusable workflow needs
**Work Item:** ADR-0012 packet 08

## Purpose

This audit establishes the baseline for caller workflows that invoke reusable workflows from `HoneyDrunk.Actions`. Under `workflow_call`, the callee's `permissions:` block is documentary only; the effective `GITHUB_TOKEN` scope is set by the caller workflow/job. A caller with omitted or under-granted permissions can fail at workflow-load time, then later surface as a stale Grid Health signal. This document closes ADR-0012 Gap 3 by recording the current static state and any follow-up needed.

## Reference Baseline

Canonical baselines come from [`HoneyDrunk.Actions/docs/consumer-usage.md`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/docs/consumer-usage.md#caller-permissions--the-load-bearing-rule), per ADR-0012 D9. For reusable workflows not explicitly listed there, this audit derives the minimum from the callee workflow's declared top-level and job-level `permissions:` blocks in the local `HoneyDrunk.Actions` checkout.

## Method

- Source: local checkouts under `C:\Users\tatte\source\repos\HoneyDrunkStudios`.
- Included repos: directories named `HoneyDrunk.*` with `.github/workflows/*.yml` files.
- Detection: parsed caller jobs whose `uses:` target starts with `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/`.
- Comparison: job-level `permissions:` when present, otherwise top-level workflow `permissions:`; status is PASS only when the effective caller permissions cover the baseline.
- No GitHub writes were performed; no follow-up issues were filed in this pass.

## Summary

- Repos with callers: 22
- Caller jobs audited: 149
- PASS: 129
- FAIL: 20
- REVIEW: 0

## Follow-up Required

The following caller jobs were missing or under-granted relative to the baseline. Per Oleg's current instruction, this audit records them only; no PRs or issues were opened.

| Repo | Workflow | Calls | Scope | Missing / Notes |
|---|---|---|---|---|
| `HoneyDrunk.Agents` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Agents` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Architecture` | `file-work-items.yml` | `file-work-items.yml` | missing | derived from callee workflow permissions; missing/under-granted contents: read; no explicit caller permissions block found |
| `HoneyDrunk.Audit` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Capabilities` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Capabilities` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Data` | `nightly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Data` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Flow` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Flow` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Knowledge` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Knowledge` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Memory` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Memory` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Notify` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Observe` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Operator` | `pr.yml` | `pr-core.yml` | job | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Operator` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Pulse` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| `HoneyDrunk.Vault.Rotation` | `publish.yml` | `release.yml` | top-level | consumer-usage.md canonical baseline; missing/under-granted security-events: write |

## Audit Results

| Status | Repo | Caller workflow | Reusable workflow | Permission scope | Effective caller permissions | Baseline | Notes |
|---|---|---|---|---|---|---|---|
| PASS | `HoneyDrunk.Actions` | `coverage-baseline-ratchet.yml` | `job-build-and-test.yml` | job | checks: write, contents: read | none | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-core.yml` | `job-build-and-test.yml` | job | checks: write, contents: read | none | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-core.yml` | `job-static-analysis.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-core.yml` | `job-secret-scan.yml` | top-level | checks: write, contents: read, pull-requests: write | none | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-core.yml` | `job-dependency-scan.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-core.yml` | `job-codeql.yml` | job | contents: read, security-events: write | contents: read, security-events: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-build-and-test.yml` | job | checks: write, contents: read | none | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-coverage-analysis.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-api-compatibility.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-static-analysis.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-secret-scan.yml` | job | contents: read | none | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-dependency-scan.yml` | job | contents: read | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Actions` | `pr-sdk.yml` | `job-codeql.yml` | job | contents: read, security-events: write | contents: read, security-events: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Agents` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Agents` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Agents` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Agents` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Agents` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.AI` | `api-compatibility.yml` | `job-api-compatibility.yml` | top-level | contents: read, pull-requests: write | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.AI` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.AI` | `nightly-security.yml` | `nightly-security.yml` | job | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.AI` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.AI` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.AI` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.AI` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.AI` | `weekly-deps.yml` | `nightly-deps.yml` | job | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Architecture` | `file-work-items.yml` | `file-work-items.yml` | missing | none | contents: read | derived from callee workflow permissions; missing/under-granted contents: read; no explicit caller permissions block found |
| PASS | `HoneyDrunk.Architecture` | `grid-review-request.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Audit` | `api-compatibility.yml` | `job-api-compatibility.yml` | top-level | contents: read, pull-requests: write | contents: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Audit` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Audit` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Audit` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Audit` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Audit` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Audit` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Auth` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Auth` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Auth` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Auth` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Auth` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Auth` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Auth` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Auth` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Capabilities` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Capabilities` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Capabilities` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Capabilities` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Capabilities` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Communications` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Communications` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Communications` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Communications` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Communications` | `release-abstractions.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Communications` | `release-runtime.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Data` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| FAIL | `HoneyDrunk.Data` | `nightly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Data` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Data` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Data` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Data` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Data` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Data` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Data` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Flow` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Flow` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Flow` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Flow` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Flow` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Kernel` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Kernel` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Kernel` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Kernel` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Kernel` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Kernel` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Kernel` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Kernel` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Knowledge` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Knowledge` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Knowledge` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Knowledge` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Knowledge` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Memory` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Memory` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Memory` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Memory` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Memory` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Notify` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Notify` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Notify` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Notify` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Notify` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Notify` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Notify` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Notify` | `release-functions.yml` | `job-deploy-function.yml` | top-level | contents: read, id-token: write | contents: read, id-token: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Notify` | `release-worker.yml` | `job-deploy-container-app.yml` | top-level | contents: read, id-token: write | contents: read, id-token: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Notify` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Observe` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Observe` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Observe` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Observe` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Observe` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Observe` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Operator` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Operator` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Operator` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Operator` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Operator` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Pulse` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Pulse` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Pulse` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Pulse` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Pulse` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Pulse` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Pulse` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Pulse` | `release-collector.yml` | `job-deploy-container-app.yml` | top-level | contents: read, id-token: write | contents: read, id-token: write | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Pulse` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline; missing/under-granted issues: write |
| PASS | `HoneyDrunk.Standards` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Standards` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Standards` | `validate-pr.yml` | `pr-core.yml` | top-level | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Transport` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Transport` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Transport` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Transport` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Transport` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Transport` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Transport` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Transport` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Vault` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Vault` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Vault` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault.Rotation` | `deploy.yml` | `job-deploy-function.yml` | top-level | contents: read, id-token: write | contents: read, id-token: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault.Rotation` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| FAIL | `HoneyDrunk.Vault.Rotation` | `publish.yml` | `release.yml` | top-level | contents: write, id-token: write, packages: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline; missing/under-granted security-events: write |
| PASS | `HoneyDrunk.Vault.Rotation` | `validate-pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Vault.Rotation` | `validate-pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Web.Rest` | `hive-field-mirror.yml` | `hive-field-mirror.yml` | top-level | contents: read, issues: read | contents: read, issues: read | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Web.Rest` | `nightly-security.yml` | `nightly-security.yml` | top-level | contents: read, issues: write, security-events: write | contents: read, issues: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Web.Rest` | `pr-review.yml` | `job-review-request.yml` | top-level | contents: read, issues: write, pull-requests: read | contents: read, issues: write, pull-requests: read | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Web.Rest` | `pr.yml` | `pr-core.yml` | job | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | checks: write, contents: read, issues: write, pull-requests: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Web.Rest` | `pr.yml` | `job-sonarcloud.yml` | job | checks: write, contents: read, pull-requests: write | checks: write, contents: read, pull-requests: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Web.Rest` | `pr.yml` | `coverage-baseline-ratchet.yml` | job | checks: write, contents: write | checks: write, contents: write | derived from callee workflow permissions |
| PASS | `HoneyDrunk.Web.Rest` | `publish.yml` | `release.yml` | job | contents: read, id-token: write, packages: write, security-events: write | contents: read, id-token: write, packages: write, security-events: write | consumer-usage.md canonical baseline |
| PASS | `HoneyDrunk.Web.Rest` | `weekly-deps.yml` | `nightly-deps.yml` | top-level | contents: write, issues: write, pull-requests: write | contents: write, issues: write, pull-requests: write | consumer-usage.md canonical baseline |

## Cadence

This is a one-time ADR-0012 baseline audit. Re-run it when Grid Health reports a new stale/missing caller workflow, when a new Grid repo is added, or when `HoneyDrunk.Actions/docs/consumer-usage.md` changes a caller-permissions contract.

## Cross-references

- [ADR-0012: Grid CI/CD Control Plane](../adrs/ADR-0012-grid-cicd-control-plane.md)
- [Grid invariants](../constitution/invariants.md) — invariant 39
- [HoneyDrunk.Actions consumer usage](https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/docs/consumer-usage.md#caller-permissions--the-load-bearing-rule)
- [ADR-0012 packet 05: consumer usage refresh](../generated/work-items/active/adr-0012-grid-cicd-control-plane/05-actions-consumer-usage-refresh.md)
