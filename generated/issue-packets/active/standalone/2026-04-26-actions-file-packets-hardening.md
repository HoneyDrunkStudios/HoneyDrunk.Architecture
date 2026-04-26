---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ci-cd", "ops", "automation"]
dependencies: []
adrs: ["ADR-0008", "ADR-0012"]
initiative: standalone
node: honeydrunk-actions
actor: Agent
---

# Feature: Harden file-packets — partial-failure recovery, GitHub App auth, GraphQL cost reduction

## Summary

The packet-filing workflow in `HoneyDrunk.Actions` hit a GraphQL rate-limit mid-run on 2026-04-26 while filing the ADR-0011 wave (8 packets). The failure exposed three real gaps:

1. The dependency-linking pass at `scripts/file-packets.sh:381` only acts on packets filed in the *current* run (`NEW_PACKETS` set, line 386). When a run partial-fails, every successfully-filed packet that came before the failure point ends up with its issue created but its blocking edges never wired — and a re-run won't fix it, because those packets are now "already filed" and the dep-linking pass skips them.
2. The workflow authenticates as the solo dev's PAT (`HIVE_FIELD_MIRROR_TOKEN`), sharing the 5,000/hour GraphQL quota with every interactive `gh` call, every Claude Code session, every other agent's API traffic. Even a modest Wave can starve the workflow when other activity drains the bucket first.
3. The mirror script re-resolves project ID + field IDs + option IDs *per packet* by calling `gh project view` and `gh api graphql` repeatedly. For an 8-packet wave, that's an avoidable ~8x duplication of metadata queries that a single up-front lookup would replace.

This packet fixes all three, in the same place, in one PR.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — script + reusable workflow live here.

The Architecture-side caller workflow (`HoneyDrunk.Architecture/.github/workflows/file-packets.yml`) needs a one-line secret swap to use the new auth path. That swap is in-scope for this packet's PR (cross-repo via the same author) — the change is small and tightly coupled, and splitting it would leave the Architecture caller broken between merges.

## Motivation

Wave 1 of ADR-0011 demonstrated the full failure mode: 7 of 8 packets filed cleanly, packet 07 hit `GraphQL: API rate limit exceeded` mid-mirror, the script `exit 1`'d, the manifest commit step preserved the 7 manifest entries (per the workflow's `if: always()` clause), but **no blocking edges were wired for any of the 8 packets** because the dep-linking pass runs after the for-loop and never executed. Re-running the workflow won't fix this — the 7 already-filed packets are skipped, and the dep-linking pass only acts on the new packet.

A solo-dev-scale Grid will hit this again. The fix is structural, not "be careful next time":

- **Idempotency.** A re-run after partial failure should leave the system in the same state as a clean first run — every packet filed, every blocking edge wired, no duplicates, no missed comments.
- **Quota isolation.** The workflow should not compete with the developer's interactive token bucket. A dedicated GitHub App installed on the Grid org gives the workflow its own 5,000/hour ceiling (scaling to 10,000 once the Grid crosses 16 repos) independent of all other token activity.
- **Cheaper per-packet cost.** The mirror script's per-packet metadata re-resolution is pure waste. Cache once, pass to all packets in the batch. Same correctness, fewer GraphQL points, more headroom before any future cap.

## Proposed Implementation

Three changes, one PR.

### Change A — Dependency-linking pass acts on every packet in the manifest

**File:** `scripts/file-packets.sh`

**Current behavior** (lines 379–433):
- The `for packet in "$PACKETS_DIR_ABS"/**/*.md; do` loop at line 383 iterates every packet on disk.
- The guard at line 386, `[[ -n "${NEW_PACKETS[$rel]:-}" ]] || continue`, restricts the pass to packets filed during the current run.
- Rationale in the existing comment (lines 379–380): "only for packets filed during THIS run, so re-runs do not post duplicate `Blocked by` comments on issues we already linked."

**New behavior:**
- Drop the `NEW_PACKETS` guard; iterate every packet in the manifest.
- Replace the duplicate-comment protection with a per-issue check: before posting, query the dependent issue's existing comment list (REST `gh api repos/.../issues/N/comments`, no GraphQL cost) and skip if a comment whose body starts with `Blocked by ` and references the exact blocker URL already exists.
- This makes the pass idempotent: safe to re-run, posts each `Blocked by` exactly once per (dependent, blocker) pair, recovers blocking edges left undone by any prior partial-failure run.

**Edge case:** if a packet's `## Dependencies` is edited *after* filing (packets are supposed to be immutable per ADR-0008 invariant 24, but accidents happen), the new pass will pick up the new dependency on the next run. Acceptable — it's the same direction the immutability rule pushes.

### Change B — GitHub App authentication

**Files:**
- `.github/workflows/file-packets.yml` (Actions reusable workflow)
- `HoneyDrunk.Architecture/.github/workflows/file-packets.yml` (Architecture caller)

**New auth path:**
1. The reusable workflow accepts two new optional inputs: `app-id` (string) and `app-private-key` (secret). If both are provided, it runs `actions/create-github-app-token@v1` as the first step and uses the resulting installation token for `GH_TOKEN` / `HIVE_FIELD_MIRROR_TOKEN`.
2. The existing `hive-field-mirror-token` secret remains accepted as a fallback. If the App secrets are absent, the workflow falls back to the PAT path. This makes the change backwards-compatible and lets the Architecture caller cut over independently.
3. The Architecture caller workflow swaps from `secrets: hive-field-mirror-token: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}` to passing `app-id` and `app-private-key`. The PAT secret is left in place at the org level for other workflows that may still use it; only the file-packets caller stops referencing it.

**App scopes (on installation):**
- Repository permissions: `Issues: Read & Write`, `Metadata: Read`, `Contents: Write` (Architecture only — for committing the manifest).
- Organization permissions: `Projects: Read & Write` (for The Hive item add + field mirror).
- Installed on: every Grid repo that hosts a packet target_repo today (Architecture, Actions, Auth, Data, Kernel, Notify, Pulse, Standards, Transport, Vault, Vault.Rotation, Web.Rest) — and Studios when it carries .NET work in the future.

### Change C — Cache project metadata across the batch

**Files:**
- `scripts/file-packets.sh` (the batch driver)
- `scripts/hive-project-mirror.sh` (the per-issue mirror script)

**Current behavior:** for every packet in the loop, `hive-project-mirror.sh` re-runs:
- `gh project view` (line 119) — resolve project ID
- `gh project field-list` or equivalent — resolve field IDs
- `ensure_single_select_option` queries (line 181) — resolve option IDs by field name, including any per-call `gh api graphql` round-trip to fetch existing options before adding a new one

For an 8-packet batch, that's roughly 8 redundant project-metadata round-trips before the actual per-packet field updates begin.

**New behavior:**
- `file-packets.sh` resolves project ID + the full set of field IDs + the full options-by-field map **once** at the start of the run, before the for-loop, and exports the result as a JSON blob via env var (e.g. `HIVE_PROJECT_METADATA_JSON`).
- `hive-project-mirror.sh` reads `HIVE_PROJECT_METADATA_JSON` if present and skips its own per-call resolution. If the env var is absent (script invoked standalone), it falls back to the current per-call behavior — backwards-compatible for human-driven `gh` invocations.
- `ensure_single_select_option` still mutates when a new option name appears (e.g. an Initiative slug not yet on the board), but reads the cached map first to determine whether the mutation is needed. After mutating, it updates the in-process cache so a later packet in the same batch sees the new option.

**Add retry-with-backoff** to all `gh api graphql` calls in both scripts: detect HTTP 403 with `rate limit exceeded` in the response body, sleep `min(60, 2^attempt)` seconds, retry up to 3 times. After the third failure, exit with a clear error pointing the user at the rate-limit reset time. This is belt-and-suspenders against transient throttling that would otherwise abort the whole run.

## Key Files

- `scripts/file-packets.sh` (modified — Changes A and C)
- `scripts/hive-project-mirror.sh` (modified — Change C)
- `.github/workflows/file-packets.yml` (modified — Change B)
- `HoneyDrunk.Architecture/.github/workflows/file-packets.yml` (modified — Change B caller-side; cross-repo edit in same PR or paired PR)

## NuGet Dependencies

None — shell + GitHub Actions only.

## Acceptance Criteria

### Idempotency (Change A)
- [ ] Re-running the workflow after a partial failure that filed N issues but skipped the dep-linking pass results in every `Blocked by` comment being posted exactly once, with no duplicates.
- [ ] Re-running the workflow when the dep-linking pass already completed cleanly does **not** post any new `Blocked by` comments.
- [ ] A packet with `dependencies: ["RepoA#5", "RepoB#7"]` produces exactly two `Blocked by` comments on the dependent issue across all runs combined, ever.
- [ ] If a dependency entry references an issue not in the manifest, the run logs a warning and continues — does not fail.

### GitHub App auth (Change B)
- [ ] When `app-id` + `app-private-key` are provided, the reusable workflow mints an installation token via `actions/create-github-app-token@v1` and uses it for all `gh` calls.
- [ ] When only `hive-field-mirror-token` is provided, the workflow falls back to the PAT path. No change in behavior vs. today.
- [ ] When both are provided, the App path wins and the PAT secret is ignored. Logged at job start so the active path is auditable.
- [ ] The Architecture caller workflow uses the App path. The PAT secret is no longer referenced in `HoneyDrunk.Architecture/.github/workflows/file-packets.yml`.
- [ ] A run that consumes ~50 GraphQL points completes without touching the developer's PAT bucket — verified by checking `gh api graphql -f query='{ rateLimit { remaining } }'` against the dev PAT before/after the workflow run shows the same remaining value.

### Cost reduction (Change C)
- [ ] Total `gh api graphql` calls per packet drops measurably vs. baseline (target: ~50% fewer points per packet for the metadata-resolution path; field-update calls are unchanged).
- [ ] An 8-packet batch run completes within 80% of the GraphQL points the prior implementation used. Documented as a one-line note in the workflow run summary: `GraphQL points consumed: N (of 5000)`.
- [ ] `hive-project-mirror.sh` still works correctly when invoked standalone (no `HIVE_PROJECT_METADATA_JSON` env var present) — falls back to per-call resolution.
- [ ] `ensure_single_select_option` correctly mutates and updates the in-process cache when a new option name (e.g. a fresh Initiative slug) appears mid-batch.

### Retry-with-backoff (Change C)
- [ ] All `gh api graphql` calls in both scripts retry on HTTP 403 + `rate limit exceeded` up to 3 times with exponential backoff capped at 60 seconds.
- [ ] Final failure after retry exhaustion exits with a non-zero code and a message including the `resetAt` timestamp from the last error response.
- [ ] Non-rate-limit errors (404, malformed query, 5xx) do **not** trigger retries — they fail fast.

### Cross-cutting
- [ ] `actionlint` passes on the modified workflow file.
- [ ] `shellcheck` passes on both scripts (or existing exclusions are documented).
- [ ] The `Filing summary` printed at end-of-run includes a new column or footer line: `GraphQL points used: <N>`.
- [ ] No ADR text is added to README sections or shell comments per the established convention; ADR references stay in this packet and the runtime PR description.

## Human Prerequisites

The GitHub App provisioning is the human's portion of this work. It precedes the agent's PR.

### 1. Create the App in the org

Walk through GitHub's UI:

1. Org Settings → Developer Settings → GitHub Apps → **New GitHub App**
2. Name: `HoneyDrunk Hive` (display name shown on PRs and issues; pick a name that signals the App's purpose at a glance)
3. Homepage URL: `https://github.com/HoneyDrunkStudios`
4. Webhook: **disabled** (no webhook URL needed; the App is invoked from Actions only)
5. Repository permissions:
   - `Issues`: **Read and write**
   - `Metadata`: **Read-only** (mandatory)
   - `Contents`: **Read and write** (needed only on Architecture; will be installed selectively)
6. Organization permissions:
   - `Projects`: **Read and write**
7. Where can this GitHub App be installed: **Only on this account**
8. Click **Create GitHub App**

### 2. Generate and store the private key

1. After creation, scroll to the **Private keys** section → **Generate a private key**
2. The browser downloads a `.pem` file — open it as text, copy the entire contents (including the `-----BEGIN ...-----` and `-----END ...-----` lines)
3. Note the **App ID** shown at the top of the App settings page (a 6–7 digit integer)

### 3. Install the App on the Grid repos

1. From the App settings page → **Install App** in the left sidebar → click **Install** next to `HoneyDrunkStudios`
2. **Only select repositories** → tick the 12 Grid repos that host packet target_repos: Architecture, Actions, Auth, Data, Kernel, Notify, Pulse, Standards, Transport, Vault, Vault.Rotation, Web.Rest
3. Click **Install**

(Studios is excluded today per the established convention; add it later when Studios CI lands.)

### 4. Provision org secrets

In the GitHub UI:

1. Org Settings → Secrets and variables → **Actions** → **New organization secret**
2. Create `HIVE_APP_ID` with the integer App ID from step 2
3. Create `HIVE_APP_PRIVATE_KEY` with the `.pem` contents from step 2 (the full text including BEGIN/END markers)
4. For both secrets, set the access policy to **Selected repositories** and select Architecture + Actions (the two repos whose workflows reference the secrets)

### 5. Verify before merging the PR

After this packet's PR is merged but before the next agent-authored Wave runs:

1. Trigger the file-packets workflow manually via `workflow_dispatch` against a no-op packet directory (e.g. an empty test branch)
2. Confirm the run logs `Auth path: GitHub App` (Change B's start-of-run logging)
3. Confirm `gh api graphql -f query='{ rateLimit { remaining } }'` against the developer's PAT shows the same remaining value before/after the run

The PAT secret `HIVE_FIELD_MIRROR_TOKEN` is not removed yet — it stays at the org level until the next quarter's secret-hygiene sweep, in case any other workflow still references it. Removal is tracked separately as a follow-up.

## Constraints

- **Solo-dev defaults.** No reviewer required, no approval gate, no split-PR ceremony. The solo dev is the only human in the loop.
- **Backwards-compatible release.** The reusable workflow accepts both auth paths; the PAT path keeps working until the org-level secret is removed. This packet does *not* remove the PAT.
- **No ADR cross-references in code or comments.** Per established convention, decision-context belongs in this packet and the PR description, not in shell or YAML comments.
- **Lean Azure tags don't apply** — no Azure resources are touched.
- **Public repo.** Both Actions and Architecture are public; the App's private key is never committed, never echoed in logs, never appears in any error message. The `actions/create-github-app-token@v1` action handles redaction natively.
- **Don't bypass `actionlint` / `shellcheck`** — fix lint findings rather than suppressing them.

## Referenced ADR Decisions

**ADR-0008 D6 — Batch packet-filing.** This packet hardens the filing pipeline ADR-0008 D6 specified. The shape (packet → issue → board → PR → merge) is unchanged; the underlying script becomes idempotent and the auth path becomes a dedicated App.

**ADR-0008 invariant 24 — Packets are immutable once filed.** Change A's edge case (re-reading dependencies on every run) is consistent with the invariant: it picks up a corrected dependencies block on the next run, but the packet is supposed to be locked, so the path exists for forensic recovery rather than routine use.

**ADR-0012 — Actions as CI/CD control plane.** This packet is exactly the kind of cross-cutting CI hardening ADR-0012 placed in `HoneyDrunk.Actions`. Both files modified live there.

## Follow-up Work (out of scope)

- **Remove the `HIVE_FIELD_MIRROR_TOKEN` org secret** once a quarter passes with no workflow referencing it. Not part of this packet — secret removal is a separate hygiene sweep.
- **Extend the App to mint per-repo tokens for additional cross-cutting workflows** (nightly-security, nightly-deps) if they hit similar quota contention. Not part of this packet — only the file-packets workflow is migrated here.
- **Surface GraphQL points consumed per run as a Hive board health signal** (e.g. annotate the run summary with a moving average) — useful telemetry, but optional.
