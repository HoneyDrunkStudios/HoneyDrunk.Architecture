# ADR-0086: Pull-Based Local Worker as the Grid Review Runner

**Status:** Accepted
**Date:** 2026-05-26
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) (Accepted) built the **Grid Review Runner** as an OpenClaw-hosted Codex execution backed by a signed GitHub-to-OpenClaw webhook. D1 of that ADR committed the trigger rail (`job-review-request.yml` emitting an HMAC-signed webhook over Cloudflare Tunnel); D5 committed OpenClaw/Codex as the subscription-backed default execution path. [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) (Proposed) further committed the canonical four-reviewer stack, where Reviewer 3 (Codex via OpenClaw) and Reviewer 4 (Claude Code on the web GitHub integration, post June 15 2026) are the two Grid-aware paths that satisfy [Invariant 53](../constitution/invariants.md) on substantive PRs. [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) (Proposed) named the always-on home server as the preferred host for the ADR-0044 webhook bridge and Cloudflare Tunnel.

In practice — over the weeks since ADR-0044 landed — that build has been **unreliable**. Three failure modes compound:

- **Webhook delivery flakes.** GitHub redelivery is best-effort; the bridge has missed `synchronize` events on long PR sessions, and the operator has no inexpensive way to tell whether a missing review is "the runner declined" or "the webhook never arrived."
- **Tunnel uptime is operator-coupled.** Cloudflare Tunnel on the home server is fine when the home server is fine; it is also the single inbound path. When the operator travels, when the home server reboots, when the tunnel daemon hiccups, the inbound rail is down.
- **OpenClaw process stability** is improving but is not yet a "set it and forget it" runtime. Crashes, session-credential expiry, and dashboard-coupled state make "did the review run" a non-trivial question.

The architectural mismatch underneath these symptoms is that the chosen shape — an **always-on inbound HTTP receiver on operator infrastructure** — does not match a solo-operator setup where the operator travels with the laptop, the home server is a single low-power box (ADR-0081 D3), and there is no pager rotation absorbing webhook misses. The shape is sound for a team-with-on-call; it is mis-sized here. ADR-0044's poll/replay fallback (D1) acknowledges this implicitly by carrying a backup transport, but the **primary** transport remains the failure-prone one.

What ADR-0044 got *right* — the load-bearing parts — is unaffected by transport choice:

- The **context-loading contract** (D2) — invariants, governing ADRs, catalogs, per-Node overview/boundaries/invariants, `copilot/pr-review-rules.md`, packet via PR-body link, PR diff — is a property of the agent prompt, not the transport.
- The **twenty-category rubric and upstream-awareness clause** (D3) bind every authoring and review surface; the transport carries diffs, not categories.
- The **`.honeydrunk-review.yaml` per-repo config** (D4) is a YAML file in the target repo, read by the runner regardless of how the runner was triggered.
- The **authorship classification** (D6), **PR-size discipline** (D7), **multi-perspective on high-risk Nodes** (D8), **post-merge sampling audit** (D9), and **advisory posture** (D10, preserving ADR-0011 D5) are disciplines that survive any substrate change.

The forcing function is therefore narrow and clean: **change the transport and the execution substrate; preserve the discipline.** This ADR proposes to do exactly that — pull the trigger inward (the operator's worker polls GitHub for PRs that need review) instead of receiving it outward (GitHub posts a webhook into operator infrastructure), and to run the agent under the operator's existing subscription CLIs (Codex CLI under ChatGPT Pro, Claude Code CLI under Claude Max) instead of through the OpenClaw process.

The new shape is small, boring, and standard: a cheap GitHub Action normalizes managed PR labels, then enqueues a review request by **labelling and commenting** on the PR; a **local scheduled agent runner** on the always-on home server (per [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md)) polls GitHub on a 1–5-minute cadence, claims one PR at a time via a label swap, runs the canonical `.claude/agents/review.md` agent locally under subscription auth, synthesizes independent Codex CLI and Claude Code CLI findings when both are required, and posts the verdict back to the PR. No inbound webhook. No tunnel for review traffic. No OpenClaw on the review path. The substrate change is invisible to the agent prompt — the same `.claude/agents/review.md` runs on either path per [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md)'s source-of-truth rule.

The operator also wants to stop treating OpenClaw as the permanent home for other scheduled agent work. The same reliability and portability concerns apply to `hive-sync` and the HoneyDrunk.Lore sourcing / ingest / signal-review jobs: they are scheduled or manually-invoked agent jobs, they need durable logs/state, they sometimes edit repos or open PRs, and they should be movable from a workstation to the home server or a cloud VM without rewriting the job. ADR-0086 therefore commits the **runner framework**, not merely a one-off review script. The Grid Review Runner is the first job type on that framework; `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review are first-class job specs in the same initiative.

This ADR is **Accepted**. It captures the transport and substrate change the operator is making. The poll interval (60–120 s during operator working hours), runner language (PowerShell), Reviewer 4 substrate (Claude Code CLI under Max via the local runner), stale-claim sweep threshold (15 min recommended), GitHub auth shape (reuse the existing ADR-0044 `review-agent` GitHub App identity where possible, not the operator's `gh` CLI session), managed PR-label normalization in HoneyDrunk.Actions, dual Codex/Claude review with synthesis for substantive high-risk work, portable job specs for review / hive-sync / Lore scheduled work, and Task Scheduler auto-start/restart posture are pinned by operator decision. The precise runner file layout and the App's installation-token caching shape are pinned by the implementing packet once a one-repo pilot runs against `HoneyDrunk.Architecture`.

## Decision

The decision has twelve bound sub-decisions. D1–D4 commit the new transport and execution substrate; D5–D9 commit how the existing ADR-0044 / ADR-0079 disciplines re-express on top of the new substrate; D10–D11 commit the decommission and rollout posture; D12 names the relationships to prior ADRs explicitly so no reader has to reverse-engineer what was kept and what changed.

### D1 — Pull-based local worker is the canonical Grid Review Runner transport

The canonical critical path for an automatic Grid-aware review is:

```
GitHub PR event → cheap GitHub Action → GitHub-native queue (label + comment)
              → local worker poll → Codex CLI + Claude Code CLI when required (subscription auth)
              → synthesized PR comment + label state transition
```

The **inbound webhook is removed**. The **Cloudflare Tunnel for review traffic is removed**. **OpenClaw is removed from the review path entirely**. The Action triggers on the same `pull_request` events as ADR-0044 D1 (`opened`, `synchronize`, `ready_for_review`; skip on `draft`) and its job is to normalize managed labels and *enqueue*, not to execute. Execution moves to the local worker, which runs under the operator's existing Codex CLI / Claude Code CLI subscription sessions.

The agent definition file (`.claude/agents/review.md`) is unchanged. The substrate change is invisible to the prompt; both the old OpenClaw-hosted path and the new local-worker path consume the same canonical agent file per [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md). [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1's "drift between execution surfaces is forbidden" principle is preserved verbatim and re-expressed: the surfaces now are Codex CLI under subscription auth and Claude Code CLI under subscription auth (per D8 below), not OpenClaw + Codex.

### D2 — Enqueue mechanism is GitHub-native (label + queue comment)

The cheap GitHub Action is the only thing that runs in the cloud. It performs two GitHub API operations and then exits:

1. **Adds the `needs-agent-review` label** to the PR (creating the label on first use per the existing label-setup pattern that landed `large-pr` / `audit-sample` / `skip-review` under ADR-0044). The label is the **primary index** the worker polls against. The Action **always** adds this label on every triggering event — including `synchronize` events fired while the PR is currently `agent-review-in-progress`. The label is therefore both the queue index and the *invalidation signal* for in-flight claims; see D3 step 5.
2. **Posts or updates a single structured queue comment** on the PR carrying the review-request payload: repo (`owner/repo`), PR number, head SHA, author class (per ADR-0044 D6's `Authorship:` line), changed-file summary, packet link extracted from the PR body, and the resolved `.honeydrunk-review.yaml` settings. The comment is the **audit trail** and the metadata carrier; the label alone is sufficient for queue semantics. The Action **edits the comment's `head_sha` field in place** on every triggering event — the comment is upserted, not duplicated. This makes the comment the canonical source of "what SHA needs review" at any moment, which D3 step 5's head-SHA invalidation check relies on.

**The Action does not invoke any LLM.** Its cost is the GitHub Actions minute floor — a single label write, a single comment write, and exit. No LLM tokens are consumed in the cloud path by design.

An optional richer payload via a tiny workflow artifact is permitted as a polish phase if the comment's character budget proves tight at scale, but v1 must work with label-plus-comment alone. The artifact path is not a v1 requirement; recommending against it until observed gaps justify the complication.

The PR body's `Packet:` / `Out-of-band reason:` metadata (per the user's PR metadata convention, memory-pinned) is the source of truth for packet linking. The Action extracts it; the comment carries it forward; the worker re-reads it from the comment rather than the PR body (idempotent against later body edits during the review window).

The same Action also performs **managed PR-label normalization** before enqueue. It reads the PR title/body, linked packet metadata/frontmatter when present, changed-file paths, and existing labels, then applies the deterministic managed labels the rest of the Grid already expects: `adr-*`, `tier-*`, `wave-*`, initiative labels, `meta`, `docs`, `ci`, `bug`, `enhancement`, `dependencies`, `chore`, `security`, `breaking-change`, `refactor`, `test`, `infra`, `automation`, `human-only`, `blocked`, `superseded`, `new-node`, `catalog`, `contracts`, `scaffolding`, and the review-state labels above. Missing managed labels are created from labels-as-code before application; packet 06 expands labels-as-code from "four worker labels only" to the full managed-label vocabulary. The normalizer must not remove arbitrary human-applied labels outside its managed set; it only reconciles labels the Grid owns. This belongs in HoneyDrunk.Actions because labels are PR metadata, not worker execution state. The worker consumes the resulting labels; it does not infer or repair them.

### D3 — Claim protocol prevents double-processing

Concurrent workers, duplicate polls, and stale claims must converge to "the PR is reviewed exactly once per head SHA." The claim protocol uses GitHub's native primitives — label swap and comment edit — as the atomic operations:

1. **List.** The worker lists all PRs across `enabled` repos carrying the `needs-agent-review` label (single `gh api search/issues` call per tick; rate-limit-cheap at solo-dev volume).
2. **Pick.** It picks the oldest unclaimed PR (creation time of the queue comment is the order key).
3. **Swap-claim.** It atomically removes `needs-agent-review` and adds `agent-review-in-progress`, *and* edits the queue comment to record `claimed_by` (worker host identifier), `claimed_at` (ISO-8601 UTC), and `head_sha` (the SHA being reviewed). GitHub's edit-comment API is the atomic primitive; if another worker raced and the label is already gone, this worker reads the next PR in the list. The race window is bounded by GitHub API consistency, which is sufficient at the volumes in play.
4. **Stale-claim sweep.** At the top of each worker tick, before listing, the worker examines all PRs labelled `agent-review-in-progress` and swaps any claim older than **N minutes** (recommended: 15 min) with no progress comment update back to `needs-agent-review`. This recovers from worker crashes mid-review.
5. **Head-SHA invalidation during claim.** A PR can receive new commits while the worker is mid-review. The cheap Action's per-event behaviour (D2) re-adds `needs-agent-review` and updates the queue comment's `head_sha` on every `synchronize`, even when `agent-review-in-progress` is already present. The worker uses two detection points:
   - **Pre-flight (cheap):** before invoking the CLI, the worker reads the current `head_sha` from the queue comment and confirms it matches the SHA recorded in the claim. Mismatch → abort the run, swap `agent-review-in-progress` back to `needs-agent-review`, leave a one-line "claim invalidated; head advanced to <Y>" entry in the queue comment, and pick up the next PR on the next tick. No CLI invocation is wasted.
   - **Post-flight (after the CLI completes):** the worker re-reads the comment's `head_sha`. If it has advanced, the completed verdict is **discarded** (not posted), the claim is released the same way, and the next tick re-reviews against the new SHA. The wasted CLI run is the cost of a push that landed during a 1–5 minute review window; under subscription auth the marginal LLM cost is $0, only operator-machine CPU time is spent.

   The idempotency key from ADR-0044 D1 — `owner/repo#pr@headSha` — makes "review at X" and "review at Y" distinct work items by construction. A pending verdict cache keyed on `head_sha` survives crashes; a verdict for an abandoned SHA is garbage-collected on the next claim of that PR. The worker never posts a verdict whose `head_sha` differs from the PR's current `head` at post time.
6. **Complete.** On verdict post, the worker removes `agent-review-in-progress` and adds either `agent-reviewed` (no `Block` / `Request Changes` findings) or `changes-requested-by-agent` (one or more findings at those severities). The verdict body posts as a PR comment using the format already defined in `.claude/agents/review.md` (preserved from ADR-0044 D1).

The **labels carry the protocol state**; the **queue comment carries the audit trail**. The idempotency key from ADR-0044 D1 — `owner/repo#pr@headSha` — is preserved: if the worker is asked to review the same head SHA twice (stale-claim sweep, operator nudge, label re-add after a removal), it short-circuits and re-posts the cached verdict rather than re-running the agent.

Recommended values pinned by the implementing packet, not this ADR: the stale-claim N (15 min is a starting recommendation), the per-tick PR-list limit (e.g., 25), and the worker host identifier shape (recommend `<hostname>:<pid>:<workerVersion>`).

### D4 — Local scheduled agent runner is a portable job framework, not one script

The runner is intentionally small and stateless across ticks. It is a **job framework** with a boring local scheduler adapter, not a bespoke review script. Recommended baseline shape:

- **Host:** the always-on home server per [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) D1. Workstation hosting is acceptable for prototyping but the home server is the steady-state target because it survives operator travel.
- **Form factor:** a **PowerShell script** invoked by **Windows Task Scheduler** on a periodic trigger. PowerShell is the recommended language because it has the lowest resource footprint on the target host — `pwsh` is already installed on Windows 11, there is no compile step, no runtime DLL deployment, and per-tick boot is sub-second. A long-running daemon/tray variant is permitted but not required; the scheduled-task shape is the lowest-operational-burden option and the recommended default. The user explicitly favored boring plumbing here.
- **Polling cadence: 60–120 seconds during the operator's working hours is the recommended default.** Off-hours cadence tuning (e.g., 60 s during 08:00–22:00 local, 5-minute cadence 22:00–08:00) is supported trivially by two time-bounded Task Scheduler triggers, but is **not recommended at v1** — the marginal `gh api` cost between continuous and reduced cadence is negligible (1,440 vs. ~250 calls/day, both well inside GitHub's rate limit), and Strategic/scheduled agent PRs per ADR-0043 can still fire overnight, so a quieter night cadence delays those reviews without saving anything meaningful. Revisit only if observed queue throughput or API-quota pressure justifies it.
- **Startup and restart posture:** the Task Scheduler entry is installed for automatic start at logon/startup, repeats on the configured interval, restarts on failure, refuses overlapping runs (`IgnoreNew`), and writes a lightweight heartbeat/tick log. If the machine is powered off, the durable queue remains in GitHub labels/comments; when the machine returns, the next scheduled tick resumes from GitHub state and the stale-claim sweep recovers any interrupted claim. The design intentionally has no hidden local queue that can be lost on reboot.
- **Language choice may diverge from the recommendation** if the implementing packet has a specific reason (Node-equivalent tooling, an existing .NET console shape the operator wants to reuse). The contract is what matters (the claim protocol per D3, the agent invocation per D8, the verdict-posting format already pinned by `.claude/agents/review.md`). PowerShell is the lowest-resource default; alternatives must justify the additional weight.
- **Job specs:** every runnable unit is declared as data, not embedded in the scheduler. A job spec names the job id, repo checkout, trigger kind (`poll`, `schedule`, `manual`, or `label-queue`), schedule, concurrency key, timeout, prompt/agent file, agent command sequence (Codex, Claude Code, or both), allowed repo write mode (`none`, `commit`, `pr`, `comment-only`), required secrets by Vault name, expected outputs, log/state retention, and portability notes. The initial specs are:
  - `grid-review` — GitHub label/comment queue -> Codex/Claude review -> synthesized PR verdict.
  - `post-merge-audit` — audit-sample queue -> review agent audit mode -> PR comment and audit artifact.
  - `hive-sync` — scheduled/manual Architecture reconciliation job using `.claude/agents/hive-sync.md`, branch/PR output, and no direct Hive board mutations.
  - `lore-source` — scheduled Lore sourcing pass using `HoneyDrunk.Lore/tools/openclaw-lore-sourcing-prompt.md`, raw-source writes, and run summary output.
  - `lore-ingest` — scheduled Lore ingest/compile pass using `HoneyDrunk.Lore/tools/openclaw-lore-ingest-prompt.md`, `raw/` -> `wiki/` updates, index rebuilds, and safe commits.
  - `lore-signal-review` — scheduled or manual Lore signal review using `HoneyDrunk.Lore/tools/openclaw-lore-signal-review-prompt.md`, output report only, no strategy or GitHub mutations.
- **Adapter boundary:** Task Scheduler is the v1 scheduler adapter. The core runner takes a job id and a host config and can run the same job under Task Scheduler, cron/systemd, a cloud VM, or a future container host without changing the job spec. Machine-specific paths live only in host config; committed job specs use repo-relative paths and logical runtime directories.
- **Auth surfaces:**
  - **The existing ADR-0044 review-agent GitHub App identity is reused where possible** rather than creating a second app. The operator already completed that portal work; this ADR amends the existing App's use from webhook bridge to local worker. Required permissions are the minimum needed: `pull_requests: write`, `issues: write` (for labels and queue/verdict comments), and `contents: read` (for the PR diff and repo checkout). If the existing App already has additional Architecture-only write scope for ADR-0044 D9 audit-artifact follow-up work, that scope is documented and left bounded to the repos that need it; no broad content-write grant is introduced by this ADR. The existing `review-agent-github-app-*` Vault secret triplet remains the credential source unless the audit in packet 02 proves the App cannot safely be amended, in which case creating a second App requires an explicit follow-up note.
  - **Reasons the App identity is committed, not just recommended:**
    - **Scope reduction.** The operator's PAT can do anything (admin, settings, secrets). The App's installation token is bounded to the three permissions above. If the worker is ever compromised (malicious agent action, supply-chain incident on the worker host), blast radius is bounded.
    - **Audit trail clarity.** Worker actions surface under the existing review-agent App bot identity in PR timelines and audit logs — distinct from the operator's account history. Easier to read at a glance who did what, and continuous with the ADR-0044 setup already in place.
    - **ADR-0006 rotation alignment.** Installation tokens auto-rotate every hour from the App's private key. PATs are long-lived secrets that violate the rotation discipline.
    - **No `gh` session expiry surprises.** The worker does not depend on an interactive `gh auth login` state surviving reboots, OS updates, or operator inattention.
    - **Rate-limit separation.** The App's installation token gets its own 5,000-REST-calls/hour and 5,000-GraphQL-points/hour budgets, independent of the operator's interactive `gh` usage. Not load-bearing at v1 volume (worker peak is ~80 calls/hour) but cheap insurance against future bursts (post-merge audits per ADR-0044 D9, agent-driven PR storms, a second worker on the laptop for testing).
    - **Future-proofing for multi-worker.** Two workers (e.g., home server + laptop for testing) can share the same App installation without contending for `gh` session state.
  - **Codex CLI** and **Claude Code CLI** authenticated via the operator's existing subscription sessions. **`ANTHROPIC_API_KEY` and `OPENAI_API_KEY` must not be set in the worker environment** — see ADR-0079 D8's auth-precedence gotcha (preserved). The worker process inherits a deliberately minimal environment block; the implementing packet documents the env hygiene. Note that `gh` CLI auth on the worker host is **not** the worker's GitHub auth path — it may still be present for the operator's interactive use, but the worker uses the App installation token exclusively.
- **State:** the runner is per-tick stateless for queue reads — every tick re-reads the durable queue from the source of truth for that job (GitHub labels/comments for reviews, schedule + repo state for hive/Lore). Small on-disk caches are allowed for idempotency and crash recovery, but they are never the only source of work. Logs, locks, checkouts, and cache files live under a configurable runtime directory so the runner can move hosts with minimal friction.

The home server is the recommended host because of its always-on posture, but the runner is also valid on the workstation or a small cloud VM. The home server's review-webhook-bridge workload listed in [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) D1's Implementation Notes is **removed** by this ADR in favor of the pull-based runner; that edit is flagged in Follow-up Work below and is intentionally not performed in this pass because ADR-0081 is still Proposed.

### D5 — `.honeydrunk-review.yaml` runner enum update

[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D4's `runner:` field changes shape:

```yaml
runner: local-worker         # local-worker (default) | api-ci
```

- **`local-worker`** (new default) — the worker described in D1–D4 runs the agent under subscription-backed Codex CLI / Claude Code CLI.
- **`api-ci`** (preserved) — the explicit per-token API fallback. Same constraint as ADR-0044 D5: must set a non-zero `cost_cap_per_pr_usd`, must name provider/model, advisory posture preserved. Not the default.
- **`openclaw-codex`** (removed) — the v1 default per ADR-0044 D4. Repos with this value migrate to `local-worker` at cutover. The enum value is dropped from the schema.

This is a **breaking schema change**. The impact is small in practice because, per ADR-0044 D11 Phase 1, only `HoneyDrunk.Architecture` has been opted in to date. The schema-doc follow-up at `copilot/review-config-schema.md` (or wherever ADR-0044's follow-up landed) is updated by the implementing packet — flagged in Follow-up Work.

Repos without a `.honeydrunk-review.yaml` continue to be treated as `enabled: false` per ADR-0044 D4's opt-in posture.

### D6 — Cost shape under the new transport

Marginal LLM cost stays **$0 by default**:

| Item | Cost | Notes |
|---|---|---|
| GitHub Action (label + comment) | ~1 worker-minute per PR event | Within the operator's GitHub Actions monthly free minutes at solo-dev volume |
| Local worker host | Amortized via ADR-0081 home server | No incremental cost beyond the home server's existing power draw |
| Codex CLI execution | Against ChatGPT Pro allotment | Same as ADR-0079 D6 Reviewer 3 billing |
| Claude Code CLI execution | Against Claude Max subscription session | No per-token billing because no `ANTHROPIC_API_KEY` is set (per D4 and ADR-0079 D8) |
| **Marginal LLM cost** | **$0/PR by default** | |

The **`api-ci` fallback remains the only path that incurs per-token billing**, and it remains explicit and capped per repo per ADR-0044 D5 (preserved).

The worker's polling cost is one `gh api search/issues` call per tick. At a 60-second tick, that is 1,440 API calls/day across all `enabled` repos — well inside GitHub's 5,000/hour authenticated rate limit for a single token. Per-PR agent invocation cost is bounded by the CLI subscription allotments, identical to ADR-0079 D6's accounting.

### D7 — Worker availability is advisory, like agent verdicts

If the worker is offline — operator traveling, home server down, scheduled-task disabled, deliberate maintenance — PRs accumulate in the `needs-agent-review` state and **remain mergeable**. The advisory posture from [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) D5 (preserved by ADR-0044 D10, preserved here) explicitly accepts this: agent unavailability is not a merge blocker.

**The queue is the signal.** Operator visibility comes from three places:

- **GitHub mobile notifications** on label-state changes and PR comments — the operator already gets these for free.
- **The weekly ADR-0043 briefing** surfaces PRs in `needs-agent-review` older than 24 h as a backlog signal. This earns its keep because a backlog older than 24 h is exactly the case where the operator wants to know the worker is down.
- **`hive-sync` / `netrunner` runner-health reporting** (per ADR-0014's reconciliation mandate) can flag review queue depth and scheduled-job freshness as Grid-health metrics.

No pager, no alarm, no Telegram, no inbound tunnel. The queue itself is durable in GitHub and survives every worker outage.

### D8 — Multi-perspective for high-risk Nodes under the local worker

[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D8 (two independent LLM-review perspectives on high-risk Nodes) and [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D7 ([Invariant 53](../constitution/invariants.md) satisfaction via dual-model execution of the same agent) are **preserved** as discipline. Their **implementation substrate moves to the local worker**:

- **Reviewer 3 (Codex CLI under ChatGPT Pro)** runs as an independent worker pass.
- **Reviewer 4 (Claude Code CLI under Claude Max)** runs as an independent worker pass on substantive PRs touching high-risk Nodes (per `catalogs/grid-health.json`'s `review_risk_class` field from ADR-0044 D8).
- The worker records both raw verdicts as local/transient review artifacts, then runs a **synthesis step** that deduplicates matching findings, preserves source attribution (`Codex`, `Claude`, or `Both`), calls out material disagreement, and posts **one combined PR comment**. The "different model families" property that satisfies Invariant 53 is preserved verbatim without cluttering the PR timeline with parallel comments.
- The **contrarian-prompt fallback** (ADR-0044 D8) applies when only one model family is locally available for some reason — e.g., a temporary Claude Code CLI auth issue. Same model, two passes, with the second pass deliberately contrarian. Any skipped or fallback pass is explicitly named in the synthesized verdict.

**Reviewer 4 is committed to the local-CLI path** (superseding ADR-0079 D2): it runs through the same local worker using **Claude Code CLI under the operator's existing Claude Max subscription**, **today**. The June 15 2026 Claude Agent SDK credit-pool launch and the Claude Code on the web GitHub integration are no longer part of the Grid Review Runner's design. The auth-precedence gotcha (ADR-0079 D8) is preserved by enforcing the no-`ANTHROPIC_API_KEY` env-hygiene rule in the worker (per D4 above).

**Why this path:**

- **Available today.** No June 15 dependency; Invariant 53 is fully satisfiable on substantive high-risk-Node PRs immediately under the new substrate.
- **Single substrate to maintain.** One worker host, one auth model, one set of CLIs (Codex + Claude Code), one body of operational knowledge. The web-integration path would add a second execution surface running outside the operator's local worker and would require parallel observability/debugging.
- **Auth-precedence gotcha collapses to env hygiene.** No env var is set; the CLI authenticates against the operator's Max session. The gotcha becomes a one-line rule in the worker setup doc rather than a cross-substrate concern.

The web-integration path (ADR-0079 D2 as originally written) is **rejected for the Grid Review Runner's design**. If a future operator concern about model-substrate diversity emerges (e.g., the local Claude Code CLI's Max session is unavailable for an extended period and the operator wants a separate failover surface), it is re-evaluated then. ADR-0079 is amended in part accordingly (see D12).

### D9 — Post-merge sampling audit (ADR-0044 D9) preserved

Implementation note only: the audit (every Nth agent-authored merged PR per ADR-0044 D9) is just another **job spec** the runner dequeues. The audit-mode instruction block remains in the canonical `.claude/agents/review.md` per ADR-0044 D9's source-of-truth discipline; the runner selects audit mode based on a separate label (`audit-sample`, already pinned by ADR-0044) and supplies the merged PR diff plus original review artifacts.

No substrate-specific change. The audit is end-to-end the same — only the execution host moves from OpenClaw to the local scheduled agent runner.

### D10 — Decommission OpenClaw review traffic first, then migrate scheduled agent jobs

Once the local runner is operating on `HoneyDrunk.Architecture` and Phase A (per D11) is green, the OpenClaw webhook bridge for **review traffic specifically** is taken down:

- **`job-review-request.yml`'s webhook-emitting form** in `HoneyDrunk.Actions` is rewritten as the label-and-comment form per D2 (or replaced with a sibling workflow at the implementing packet's discretion; the contract is what matters, not the YAML file's name).
- **The Cloudflare Tunnel hostname for review traffic** (e.g., the `grid-review.honeydrunkstudios.com` host listed in ADR-0081 D6) is removed. Tunnels for other workloads are unaffected.
- **The webhook-signing secret** used for ADR-0044's primary path is rotated out per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)'s secret-rotation discipline. The rotation is a follow-up packet, not part of this ADR.
- **OpenClaw's other roles** continue until their replacement job specs have been installed and smoke-tested under this runner. This ADR does not rip out `hive-sync` or Lore jobs during the review cutover, but it does make their migration part of the same ADR-0086 implementation work rather than future undefined scope.

The review decommission is a **discrete cutover** at the end of Phase A: the runner proves itself on `HoneyDrunk.Architecture`, then the webhook bridge is taken down, then Phase B begins. The scheduled-job migration is separate and explicit: `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review move to runner job specs only after each job has a smoke-test record, rollback note, and output comparison against the current OpenClaw/Honeyclaw behavior. No long parallel-run period after a job is verified, but no blind cutover either.

### D11 — Phased rollout (resets ADR-0044 D11's clock)

The transport change is large enough that ADR-0044 D11's Phase 1–4 progression is **moot for the new substrate**, and the phase clock resets:

- **Phase A (new Phase 1)** — build the runner; pilot on `HoneyDrunk.Architecture` only (lowest blast radius, same rationale as ADR-0044 D11 Phase 1). Verify the four labels function, the claim protocol behaves under deliberate runner-restart and stale-claim scenarios, verdict quality matches the OpenClaw-hosted runner's, and marginal cost stays at $0. **Phase A's exit criterion is the same as ADR-0044 D11 Phase 1's**: verdict quality at least as useful as the manual local-agent invocation, reliable triggers (now meaning "reliable polling and claim semantics" instead of "reliable webhook delivery"), and near-zero marginal cost under subscription auth.
- **Phase B (new Phase 2)** — enable PR review on the other repos that ADR-0044's Phase 2 had reached (whichever those ended up being at this ADR's acceptance time). Each repo's `.honeydrunk-review.yaml` migrates from `runner: openclaw-codex` to `runner: local-worker`. The four new labels (`needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, `changes-requested-by-agent`) are added to each repo's label set via the existing label-setup pattern.
- **Phase C (new Phase 3)** — migrate scheduled agent jobs onto the same runner: `hive-sync`, Lore sourcing, Lore ingest/compile, and Lore signal review. The job specs land beside the review specs; Task Scheduler entries (or host-specific scheduler entries) invoke jobs by id; each migration records smoke-test output, rollback steps, and whether the previous OpenClaw/Honeyclaw schedule is disabled.
- **Phase D (new Phase 4)** — ramp and observability polish. Multi-perspective (D8) activates once `review_risk_class` is populated per ADR-0044 D8 (preserved). Post-merge sampling audit (D9) activates per ADR-0044 D9's preserved discipline. Runner health surfaces cover both review queue depth and scheduled-job freshness.

Each phase is a discrete go/no-go; missing Phase A's bar pauses Phase B, and missing any scheduled-job smoke test pauses that job's cutover. The OpenClaw webhook bridge is decommissioned at Phase A→Phase B cutover per D10; OpenClaw/Honeyclaw scheduled jobs are disabled per job after the corresponding ADR-0086 runner job is proven.

### D12 — Relationship to prior ADRs

| ADR | Decision | Posture under this ADR |
|---|---|---|
| [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) D5 | Review agent is advisory | **Preserved.** Worker downtime is a worker-availability problem, not a merge gate. |
| [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) D10 | Local-only, human-invoked | Already reversed by ADR-0044; this ADR keeps it reversed but moves the *automatic* trigger from cloud-webhook to pull-from-cloud-state. The manual invocation path remains available. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D1 | Build with GitHub Actions trigger rail + signed webhook → OpenClaw | **Superseded** by D1–D4 of this ADR. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D2 | Context-loading contract | **Preserved verbatim.** Substrate change is invisible to the prompt. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 | Twenty-category rubric + upstream awareness | **Preserved verbatim.** |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D4 | `.honeydrunk-review.yaml` | **Preserved** with the `runner` enum change per D5 of this ADR. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D5 | Cost guardrails; subscription-backed default | **Preserved.** The subscription-backed default is now local CLIs (Codex CLI + Claude Code CLI) rather than OpenClaw/Codex specifically. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D6 | Authorship classification | **Preserved.** |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D7 | PR-size discipline for non-`human` PRs | **Preserved.** |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D8 | Multi-perspective for high-risk Nodes | **Preserved** with implementation substrate change per D8 of this ADR. |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D9 | Post-merge sampling audit | **Preserved.** |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D10 | Relationship to ADR-0011 (D5 preserved, D10 reversed, D11 moot) | **Preserved.** |
| [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D11 | Phased rollout | **Clock reset** per D11 of this ADR. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D1 Reviewer 3 | Codex via OpenClaw | **Superseded transport-wise.** Same Codex CLI execution, same ChatGPT Pro billing, but triggered via the pull-based local worker — not via OpenClaw. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D2 Reviewer 4 | Anthropic's native Claude Code on the web GitHub integration (post June 15) | **Superseded.** Reviewer 4 runs through the local worker via Claude Code CLI under Max **today**. The June 15 dependency and the web-integration surface are removed from the Grid Review Runner's design. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D3 | Substantive-PR classifier safe-list | **Preserved.** |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D4–D5 | Greptile and generic Codex not selected | **Preserved.** |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D6 | Cost ceiling | **Preserved.** Cost shape per D6 of this ADR is consistent with ADR-0079 D6's accounting. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D7 | Invariant 53 satisfaction via dual-model execution | **Preserved.** Dual-model execution is now Codex CLI + Claude Code CLI, both under subscription auth, both under the local worker. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D8 | Auth-precedence gotcha | **Preserved.** Enforced at the worker env boundary per D4 of this ADR. |
| [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) D9 | Out-of-scope items | **Preserved.** |
| [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) D1 | Home server as automation host | **Recommended as the runner host.** The review-webhook-bridge workload listed in ADR-0081 D1's Implementation Notes is removed in favor of the pull-based runner. Scheduled agent workloads remain on their current OpenClaw/Honeyclaw schedules until the equivalent ADR-0086 runner job spec is installed and smoke-tested; then they migrate to the runner. ADR-0081's edit is flagged as Follow-up Work and intentionally not performed in this ADR pass because ADR-0081 is still Proposed. |

## Consequences

### Affected Nodes

- **HoneyDrunk.Actions** — primary affected Node. The reusable workflow that ADR-0044 D1 named `job-review-request.yml` (webhook-emitting form) is replaced by a managed-label-normalizing, label-and-comment-emitting form (sibling workflow or in-place rewrite, at the implementing packet's discretion). The webhook-bridge code paths are removed. The existing `pr-size-check`, `authorship-check`, and `audit-sample` labelling jobs (per ADR-0044 D6/D7/D9) are composed with, not replaced by, the central label normalizer.
- **HoneyDrunk.Architecture** — pilot for Phase A; OpenClaw review-runner runbook/config decommissioned; new runner config/runbook authored; job specs for review, post-merge audit, `hive-sync`, and Lore jobs documented; new directory shape for local runner state/cache/log files (recommended: under operator-machine-local path, not committed to the repo).
- **HoneyDrunk.Lore** — scheduled sourcing, ingest/compile, and signal-review prompts remain the canonical job instructions; their scheduler/runtime moves from OpenClaw/Honeyclaw to ADR-0086 runner job specs after smoke tests.
- **Home server / workstation host (per [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md))** — runs the runner process. Adds Windows Task Scheduler entries (or equivalent) for the runner's review tick and scheduled agent jobs.
- **Every `enabled` repo** — gets four new labels added (`needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, `changes-requested-by-agent`) via the existing label-setup pattern used for `large-pr` / `audit-sample` / `skip-review`. Existing labels are preserved.
- **`.claude/agents/review.md`** — **no change**. The substrate change is invisible to the prompt; this is intentional per the source-of-truth discipline.
- **`.honeydrunk-review.yaml` schema doc** (at `copilot/review-config-schema.md` or wherever ADR-0044's follow-up landed) — updated for the `runner` enum change per D5. Flagged in Follow-up Work.
- **OpenClaw workspace/runtime** — review-runner workload is removed at Phase A -> B cutover; `hive-sync` and Lore scheduled jobs are retired only after their ADR-0086 runner job specs are installed, smoke-tested, and recorded.
- **HoneyDrunk.Vault** — the webhook-signing secret used for ADR-0044's primary path is rotated out per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) discipline at cutover. No new App secret is required if the existing ADR-0044 `review-agent-github-app-*` secret triplet can be reused; packet 02 audits those secret names and documents any permission widening. The worker reads the App credentials at tick startup, exchanges them for an installation token via `POST /app/installations/{installation_id}/access_tokens`, and uses the resulting short-lived token for the tick. Rotation remains the App's native key-rotation flow per ADR-0006.
- **GitHub org (`HoneyDrunkStudios`)** — reuses the existing ADR-0044 review-agent GitHub App where possible. App permissions for the worker path: `pull_requests: write`, `issues: write`, `contents: read`; any additional repo-content write permission must be justified by the existing audit-artifact workflow and bounded to enabled repos. Installation scope: `enabled` repos only (additive as new repos are enabled per D11 Phase B/C).

### Invariants

[ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)'s two added invariants are **preserved** under this transport, with the "requests" mechanism redefined:

- **Every non-draft PR on an `enabled` repo requests an automatic Grid Review Runner pass** — "requests" now means "lands in the GitHub-native queue, processed by the local worker." Skip is via `skip-review` or `enabled: false`, both explicit and visible. Worker unavailability is surfaced as advisory/pending (queue depth signal per D7), not hidden.
- **Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge** — preserved with the local-worker substrate per D8 of this ADR; the PR-facing output is one synthesized verdict with source attribution.

[ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md)'s proposed invariants are preserved:

- The canonical PR review stack remains four reviewers (three on every PR, four on substantive PRs).
- The substantive-PR classifier remains the safe-list in ADR-0079 D3; per-PR override is forbidden.
- The Grid-aware agent's two execution paths consume the same `.claude/agents/review.md` definition; drift between paths is forbidden.
- `ANTHROPIC_API_KEY` is not set in the worker environment by default.

No new invariants are required by this ADR. Invariant numbers reconcile via `hive-sync` per [ADR-0014](./ADR-0014-mind-control.md) — this ADR does not edit `constitution/invariants.md`.

### Operational Consequences

- **No public ingress for review traffic.** The attack surface around the review path collapses to GitHub auth (for the worker's PR read/write) plus the worker's local filesystem. Cloudflare Tunnel exposure for review traffic is removed at cutover.
- **Operator notifications come from GitHub mobile** — label changes, PR comments. No Telegram, no Discord-via-tunnel, no OpenClaw dashboard required for review-runner status.
- **Runner health is split by job type.** For review jobs, queue depth and backlog older than 24 h are the health signal; for scheduled jobs, last-success timestamp, last-output path, and missed-schedule count are the health signal.
- **The worker stale-claim sweep prevents zombie reviews.** Worker crashes mid-review are recovered automatically within N minutes per D3.
- **Machine restarts are boring.** Task Scheduler restarts the runner at logon/startup and on failure; GitHub labels/comments remain the durable review queue while the machine is off, and scheduled jobs resume from repo state on the next configured trigger.
- **Pushes during in-flight review are handled deterministically.** A push that lands while the worker is reviewing the prior SHA invalidates the in-flight claim via D3 step 5; the worker discards the now-stale verdict and the next tick re-reviews against the new head. The cost is one wasted CLI run (operator-machine CPU only — marginal LLM cost is $0 under subscription auth).
- **The worker uses the existing review-agent GitHub App identity**, not the operator's account. PR timelines show review activity under the App bot, scope is bounded to the worker permissions above, and the App's installation token rotates hourly from a private key stored in HoneyDrunk.Vault per ADR-0006.
- **Review comments are consolidated.** Dual Codex/Claude runs produce one synthesized PR verdict that deduplicates findings and names disagreements instead of posting two competing comment threads.
- **The discipline-half of ADR-0044 is fully preserved.** Authorship classification, PR-size discipline, multi-perspective on high-risk Nodes, post-merge sampling audit, advisory posture — all unchanged.
- **The pre-June-15 Reviewer 4 transition state from ADR-0079 D7 collapses to nothing** under the recommended local-CLI path: Claude Code CLI under Max is available today, so Invariant 53 is fully satisfiable today. If the operator chooses the web-integration alternative, the transition state per ADR-0079 D7 persists until June 15.
- **The auth-precedence gotcha (ADR-0079 D8)** becomes a worker env-hygiene rule — easier to enforce than across a webhook bridge.
- **OpenClaw becomes a migration source, not the permanent scheduled-agent substrate.** Non-review OpenClaw/Honeyclaw jobs keep running until each equivalent runner job has a smoke test and rollback note; after that job-specific cutover, the old schedule is disabled.

### Follow-up Work

- **Audit and reuse the existing ADR-0044 review-agent GitHub App** for the local worker path. Verify permissions, installation scope, Vault secret names, and rotation procedure; widen only the minimum permissions needed for labels/comments/diff reads if the existing App is narrower.
- **Write the new managed-label-normalizing enqueue workflow in HoneyDrunk.Actions** (replacing or sibling to `job-review-request.yml`'s webhook-emitting form). The workflow must apply deterministic managed PR labels before enqueue, always re-add `needs-agent-review` on `synchronize`, and edit the queue comment's `head_sha` in place, even when `agent-review-in-progress` is currently set — see D2 and D3 step 5 for the invalidation contract. Implementing packet choice on naming and file structure.
- **Implement dual-pass synthesis** in the worker: run independent Codex and Claude passes when D8 requires both, preserve raw findings in transient artifacts, post one synthesized verdict with source attribution, and explicitly note fallback/skipped passes.
- **Implement the head-SHA invalidation logic** in the worker per D3 step 5 (pre-flight comment re-read, post-flight comment re-read, verdict discard on SHA mismatch). Pin a small on-disk pending-verdict cache keyed on `head_sha` for crash recovery.
- **Remove the OpenClaw webhook-bridge code paths** for review traffic. Tunnels and bridges for other workloads remain.
- **Author the local scheduled agent runner** (PowerShell or .NET console — implementing packet pins the language). Land it in a directory under HoneyDrunk.Architecture (recommended: `infrastructure/workers/grid-agent-runner/`) or a sibling Node, at implementing packet's discretion.
- **Author portable job specs** for `grid-review`, `post-merge-audit`, `hive-sync`, `lore-source`, `lore-ingest`, and `lore-signal-review`, with host-specific paths confined to local host config.
- **Migrate `hive-sync` to the runner** with schedule/manual triggers, branch/PR output, no direct Hive board mutations, and a smoke-test comparison against the current OpenClaw job.
- **Migrate HoneyDrunk.Lore scheduled jobs to the runner** for sourcing, ingest/compile, and signal review, preserving the existing prompt files and run-output contracts.
- **Add the worker labels and managed PR-label vocabulary** to each `enabled` repo's label set via the existing label-setup pattern.
- **Update `.honeydrunk-review.yaml` schema doc** with the new `runner` enum (drop `openclaw-codex`, add `local-worker` as default, preserve `api-ci`).
- **Rotate out the ADR-0044 webhook-signing secret** per ADR-0006 discipline at Phase A → Phase B cutover.
- **Update ADR-0081 D1's Implementation Notes** to remove the review-webhook-bridge workload bullet. **Not performed in this ADR pass** because ADR-0081 is still Proposed and the edit shape is one line — leave it to ADR-0081's acceptance/amendment cycle.
- **Wire the worker stale-claim sweep** and pin the recommended N (start at 15 minutes; tune based on observed worker-tick durations).
- **Install the worker through Task Scheduler** with startup/logon triggers, interval repetition, restart-on-failure, no-overlap settings, heartbeat/tick logging, and a documented recovery story after machine shutdown.
- **Document worker env-hygiene** (no `ANTHROPIC_API_KEY`, no `OPENAI_API_KEY`) in the operator-facing setup doc per ADR-0079 D8's auth-precedence gotcha discipline.
- **Wire runner health surfacing** per ADR-0014's reconciliation mandate: review queue depth/backlog, scheduled-job last success, missed runs, and latest output artifact path.
- **Decommission the `grid-review.honeydrunkstudios.com` (or equivalent) Cloudflare Tunnel hostname** at cutover. Other tunnel hosts are unaffected.
- **Do not edit `.claude/agents/review.md`** — the agent file is unaffected by this transport change.
- **Do not edit `constitution/invariants.md`** — invariant numbers reconcile via `hive-sync` per ADR-0014.
- **Append supersession notes** to ADR-0044 and ADR-0079 (performed by this ADR's acceptance pass).

## Alternatives Considered

### Keep the signed-webhook-to-OpenClaw transport and fix the reliability issues

Considered. The argument: tactical fixes to webhook reliability (better redelivery handling, a more robust tunnel daemon, hardening OpenClaw against crashes) preserve the existing architecture without a substrate change.

Rejected. The failure modes — tunnel uptime, OpenClaw process stability, webhook-secret rotation, inbound public exposure, the debugging cost of "why didn't this PR fire" — are **intrinsic to the inbound-webhook shape on a single-operator home setup**. No tactical fix addresses the architectural mismatch between "always-on inbound HTTP receiver on operator infrastructure" and "operator who travels with the laptop." Pull eliminates the category. Investing more in the inbound-webhook shape would be repair work on a house that does not fit the lot.

### GitHub Actions self-hosted runner on the home server instead of a pull-worker

Considered. The argument: a self-hosted GitHub Actions runner gets GitHub-native job execution on the home server without a custom worker.

Rejected. Same reliability story as OpenClaw (the runner must stay registered and online; runner-offline produces queued-but-stalled jobs); GitHub's self-hosted runner security warnings on public repos add real risk for a Grid that is default-public; the runner contract has to be maintained against GitHub's runner version evolution. The pull-worker is structurally simpler — stateless `gh` API calls, no listener state, no runner-version coupling — and uses primitives every operator already understands (Task Scheduler + a console app).

### Use a cloud queue (Azure Storage Queue, SQS, or similar) instead of GitHub labels

Considered. The argument: a real queue surfaces queue semantics (visibility timeout, dead-letter, retry counts) that GitHub labels don't, and decouples the worker from GitHub's API rate limits.

Rejected. The GitHub-native queue (label + comment) is **sufficient at solo-dev volume**, requires zero new infrastructure, is visible to humans in the PR UI, survives every reliability concern the inbound-webhook shape had, and does not add a third-party dependency to the review path. Adding a cloud queue is plumbing for a problem we don't have. If queue depth or coordination semantics become genuinely limiting at a future volume, a cloud queue is a small follow-up amendment; presuming the need up front is decision-under-uncertainty.

### Stick with ADR-0044 / ADR-0079 and wait for OpenClaw maturity

Considered. The argument: OpenClaw is improving; another few months of stability work could fix the reliability symptoms without a substrate change.

Rejected. The operator has lived with OpenClaw's unreliability for weeks and is making a direct request to change substrate; "wait for maturity" prioritizes a tool we don't control over the review discipline we depend on. The review discipline is more important than the substrate choice; a substrate that does not impede the discipline is the right move now, even if OpenClaw matures later (OpenClaw's other roles continue regardless).

### Keep OpenClaw for hive-sync and Lore while only reviews move

Considered. The argument: review reliability is the acute problem, while `hive-sync` and Lore jobs already run on schedules and can remain on OpenClaw/Honeyclaw until a later cleanup.

Rejected as the steady state. Those jobs are the same class of work as the review runner: scheduled/manual agent execution with repo checkouts, durable output, secrets, logs, and an operator-host dependency. Keeping two substrates would leave the Grid with two scheduler stories and two recovery stories. ADR-0086 therefore builds the common runner now and migrates those jobs by spec, with smoke tests before each old schedule is disabled.

### Use GitHub Actions cron for hive-sync and Lore jobs

Considered. The argument: GitHub Actions already provides schedules, logs, and repo checkout, so scheduled agent jobs could move there instead of to the local runner.

Rejected for the jobs that require subscription-backed Codex/Claude Code sessions or local operator context. Actions is still the right place for cheap trigger rails and deterministic metadata work, but not for the LLM-agent execution that this ADR deliberately moves under subscription CLIs and portable host config. A future cloud VM can host the same runner without changing job specs; moving the jobs into GitHub Actions would couple them to a different execution and auth model.

### Move to Anthropic's Claude Code on the web GitHub integration for everything (drop Codex entirely)

Considered. The argument: single-vendor simplicity; one execution surface to maintain; the June 15 credit-pool launch makes this affordable.

Rejected. The dual-model satisfaction of [Invariant 53](../constitution/invariants.md) per ADR-0079 D7 is **load-bearing** for high-risk-Node reviews. Single-vendor-everywhere loses model-family independence, which is the explicit shape of the high-risk-PR safeguard. The right move is to keep both model families on the local-worker substrate (Codex CLI + Claude Code CLI), not to consolidate on one.

### Make the worker push to a centralized review log (S3 / Azure Blob / etc.) instead of posting back to the PR

Considered. The argument: a separate review log is easier to query at scale, supports cross-PR analytics, and decouples review history from PR lifecycle.

Rejected. The **GitHub PR is the system of record** per ADR-0011 D1. A separate log is duplicate state and would need a reconciliation discipline against the PR. PR comments + check runs + labels are the surface humans and other tools already read; piping review verdicts to a parallel log is solving a problem the Grid does not have. If a post-merge analytics use case emerges, the existing `generated/post-merge-audits/` directory (per ADR-0044 D9) is the right place to land it — local files committed to the Architecture repo, not a separate log service.

## References

- [`constitution/charter.md`](../constitution/charter.md) — anti-performing-visibility warning; the substrate change in this ADR removes plumbing, not adds it
- [`constitution/invariants.md`](../constitution/invariants.md) — Invariant 53 (two independent perspectives on high-risk Nodes per ADR-0046)
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — secret-rotation discipline used to rotate out the ADR-0044 webhook-signing secret at cutover
- [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md) — `.claude/agents/review.md` as source of truth; both old and new substrates consume the same agent file
- [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) — base code-review-and-merge flow; D5 advisory posture preserved
- [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) — HoneyDrunk.Actions, the cheap-trigger-rail host
- [ADR-0014](./ADR-0014-mind-control.md) — `hive-sync` / `netrunner` reconciliation; invariant-number reconciliation
- [ADR-0043](./ADR-0043-weekly-strategic-tactical-reactive-briefing.md) — the briefing that surfaces backlog > 24 h as a worker-health signal
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — Grid-aware cloud code reviewer (superseded in part by this ADR; D1 and D5 superseded, other D's preserved)
- [ADR-0046](./ADR-0046-specialist-review-agents.md) — specialist review agents (Invariant 53 source)
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — cost governance (reviewer-stack cost monitoring)
- [ADR-0079](./ADR-0079-multi-perspective-pr-review-stack.md) — multi-perspective PR review stack (partially superseded by this ADR; D1 Reviewer 3 transport, D2 Reviewer 4 recommendation)
- [ADR-0081](./ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md) — home server (recommended worker host; D1 review-webhook-bridge workload removed as Follow-up Work)
- [`../infrastructure/openclaw/hive-sync.md`](../infrastructure/openclaw/hive-sync.md) — current OpenClaw-hosted hive-sync runtime contract migrated by this ADR's runner framework
