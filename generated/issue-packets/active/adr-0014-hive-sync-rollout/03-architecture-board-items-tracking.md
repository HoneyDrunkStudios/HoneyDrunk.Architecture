---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0014", "wave-3"]
dependencies: ["adr-0014-hive-sync-rollout/02-architecture-packet-lifecycle"]
adrs: ["ADR-0014"]
accepts: ["ADR-0014"]
wave: 3
initiative: adr-0014-hive-sync-rollout
node: honeydrunk-architecture
---

# Feature: Track non-initiative board items in `initiatives/board-items.md`

## Summary
Extend `.claude/agents/hive-sync.md` with a GraphQL query against The Hive (org Project #4) and a new tracking file `initiatives/board-items.md` listing every issue on The Hive that did not originate from the packet pipeline. These include nightly-security-job issues, future grid-health-aggregator issues, and any other issue mirrored onto The Hive without a corresponding `filed-packets.json` entry. Add the **board-coverage invariant** to `constitution/invariants.md` under the existing "Hive Sync Invariants" section (its numerical position is determined at execution time — see Part C). The first agent run after this packet lands seeds `board-items.md` from the current Hive state. After this packet, the Architecture repo is a complete mirror of The Hive — every issue is either in an initiative tracking file or in `board-items.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0014 D3 names the gap: the `hive-field-mirror` workflow (landed via Actions#22) wires nightly-security issues onto The Hive, but the Architecture repo has no surface for them. They're real work items with board presence, but `initiatives-sync`/`hive-sync` ignores them because they have no entry in `filed-packets.json`. Over time, this gap will widen: ADR-0012's grid-health aggregator (D6) will create per-repo failure issues; future dependency bots and observability alerts will create more. Each new auto-source is invisible to the Architecture repo today.

This packet closes the gap **structurally** — by querying The Hive board directly and reconciling against the packet-sourced set, rather than per-source-wiring. Any new automated issue source that lands on The Hive is automatically picked up on the next `hive-sync` run with no agent changes.

This packet also encodes the **board-coverage invariant**: every issue on The Hive must appear in either an initiative tracking file or `board-items.md`. After this packet, "what is the Grid working on right now?" can be answered from the Architecture repo alone, without consulting GitHub directly.

**Note on invariant numbering.** ADR-0014's authored text names this invariant as #39 and the lifecycle invariant (Packet 02) as #40. Those numbers were correct at authorship but conflict with ADR-0012's pending acceptance, which renumbers its own invariants to 37-41. To avoid the collision, this packet does **not** hardcode an integer — it appends the board-coverage invariant inside the existing "Hive Sync Invariants" section using the next available number after the current max. The acceptance criteria pin the **textual content** of the invariant, not the integer. See Part C for the lookup procedure.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code (no `.cs` files). No secrets.

### Part A — Add a new tracking step to `hive-sync.md`

In `.claude/agents/hive-sync.md`, insert a new Step **between the existing Step 7 (Archive Complete Initiatives) and Step 8 (Move Closed Packets to completed/, added by Packet 02)**. The new step is numbered Step 8, the old Step 8 becomes Step 9, and the old Step 9 becomes Step 10. Renumber all section headings accordingly. The new step reads:

```markdown
### Step 8: Reconcile Non-Initiative Board Items

Query The Hive board (org Project #4) via GraphQL, subtract the set of issues already known from `filed-packets.json`, and write the remainder to `initiatives/board-items.md`.

**8a. Query The Hive board.**

```bash
gh api graphql -f query='
{
  organization(login: "HoneyDrunkStudios") {
    projectV2(number: 4) {
      items(first: 200) {
        nodes {
          content {
            ... on Issue {
              number
              title
              url
              state
              createdAt
              closedAt
              labels(first: 20) { nodes { name } }
              repository { name }
            }
          }
        }
      }
    }
  }
}' > /tmp/hive-items.json
```

If the board has more than 200 items, paginate using `pageInfo` and `endCursor`. Treat empty `content` (draft items, PRs, etc.) as not-an-issue and skip.

**8b. Compute the non-initiative set.**

Read `generated/issue-packets/filed-packets.json` and collect the value side (the set of issue URLs that originated from packets). Read `/tmp/hive-items.json` and filter to issues whose `url` is **not** in that set. The remainder are non-initiative items.

**8c. Categorize.**

For each non-initiative item, derive a category label for the table:

- Labels include `security` and `automated` → `security`
- Title starts with `[grid-health]` → `grid-health`
- Otherwise → `other`

The category does not affect tracking; it just helps a human reading the file understand the source at a glance. New categories may be added without editing the agent — the categorization is purely cosmetic.

**8d. Render `initiatives/board-items.md`.**

Fully rewrite the file each run. The structure is:

```markdown
# Board Items — Non-Initiative Work

Tracked automatically by the hive-sync agent. Items listed here are on
The Hive but did not originate from a scoped issue packet. The agent does
not set or modify Hive fields — that is the responsibility of the mirror
workflow (for auto-wired issues) or the file-issues agent (for packets).
This file is read-only with respect to The Hive board.

Last synced: {YYYY-MM-DD}

## Open

| Issue | Repo | Category | Labels | Opened |
|-------|------|----------|--------|--------|
| [#42 ...](url) | HoneyDrunk.Vault | security | security, automated | 2026-04-15 |

## Recently Closed (last 30 days)

| Issue | Repo | Category | Labels | Opened | Closed |
|-------|------|----------|--------|--------|--------|
| [#38 ...](url) | HoneyDrunk.Auth | security | security, automated | 2026-04-10 | 2026-04-12 |
```

Rules:

- **Open items are always listed.** No date cutoff.
- **Closed items are listed for 30 days after their `closedAt` date**, then dropped. The agent computes the cutoff as `today - 30 days` and drops any closed item with `closedAt < cutoff`.
- **The file is fully rewritten each run.** No append-only history. The list reflects current reality at sync time.
- **Empty state is a single line, not missing tables.** When no non-initiative items exist (Open is empty AND Recently Closed is empty), replace both tables with the line `_No non-initiative items on The Hive._`. The file itself still exists.
- **Issue title rendering:** strip leading whitespace and unicode escape characters; truncate to 80 chars with an ellipsis if longer. The hyperlink target is the issue URL.

**8e. No Hive writes.**

The agent does **not** call any GraphQL mutation against the project board. It does not set fields, change status, modify labels, or close issues. This step is read-only with respect to The Hive. Field-setting for auto-wired issues is the `hive-field-mirror` workflow's job; field-setting for packet-sourced issues is the `file-issues` agent's job.
```

### Part B — Update Constraints in `hive-sync.md`

Append two new bullets to the Constraints block (which Packet 02 rewrote). The new bullets read:

```markdown
- The `hive-sync` agent is **read-only with respect to The Hive board**. It reads project items via GraphQL but never calls a mutation to set fields, change status, modify labels, or close issues. Hive-field writes are owned by the `hive-field-mirror` workflow (for auto-wired issues) and the `file-issues` agent (for packet-sourced issues).
- The `initiatives/board-items.md` file is **fully rewritten on every sync run**. The agent does not append history or preserve hand-written content in this file — it is a current-state surface, not a journal. Any hand-edits will be overwritten on the next run.
```

### Part C — Add the board-coverage invariant

In `constitution/invariants.md`, locate the "Hive Sync Invariants" section that Packet 02 created (containing the packet-lifecycle invariant). **Append** the board-coverage invariant inside that section.

**Step 1: Determine the invariant number.**

Read `constitution/invariants.md` and find the highest existing invariant number. The new invariant's number is `max + 1`. Do **not** hardcode `39` or any other integer. Append the new invariant at the end of the "Hive Sync Invariants" section after the lifecycle invariant.

```bash
# Lookup pattern (the executing agent runs this or equivalent)
COVERAGE_NUM=$(grep -oE '^[0-9]+\.' constitution/invariants.md | tr -d '.' | sort -n | tail -1 | awk '{print $1+1}')
echo "Board-coverage invariant will be numbered ${COVERAGE_NUM}"
```

After this packet lands, the "Hive Sync Invariants" section contains the lifecycle invariant followed by the board-coverage invariant — in **insertion order**, not necessarily ascending integer order if other ADRs renumbered intervening invariants. Insertion order is fine; readers parse by name and reference, not numeric position.

**Step 2: Append the invariant.**

Use this template, substituting `{N}` with the value from Step 1:

```markdown
{N}. **The Architecture repo tracks all Hive board items.** Every issue on The Hive (org Project #4) is represented in either an initiative tracking file (for packet-originated work, including `active-initiatives.md`, `archived-initiatives.md`, etc.) or `initiatives/board-items.md` (for non-initiative work — nightly-security issues, grid-health-aggregator issues, and any other issue mirrored onto The Hive without a `filed-packets.json` entry). The `hive-sync` agent is responsible for maintaining this correspondence and runs Monday/Thursday on schedule plus manual dispatch. See ADR-0014 D1, D3.
```

**Existing-section safety net.** If the "Hive Sync Invariants" section does not exist (because Packet 02 was reverted or has not yet landed), this packet is out of order — its dependency declaration requires Packet 02 first. Surface the error rather than creating the section here.

**Cross-reference safety.** ADR-0014's authored text names this invariant as "39" and the lifecycle invariant (Packet 02) as "40". Those numbers may not match the live integers chosen at execution time. The agent must not edit the ADR-0014 source to "correct" the numbers — the ADR carries an explicit parenthetical about this. Acceptance criteria below pin the **textual content** of the invariant, not the integer.

### Part D — Create `initiatives/board-items.md`

Create the file `initiatives/board-items.md` with the structure described in Part A Step 8d, populated with **the current state of The Hive** at this packet's execution time. The first run is the seed.

**Seed scope at scoping time** (snapshot, may shift between scoping and execution): the seed will primarily include nightly-security issues from the `nightly-security` workflow (per ADR-0009), which fires on schedule against every Grid repo. The exact issue list is not enumerated here because (a) it changes between scoping and execution, and (b) the agent must derive the seed from live GraphQL data, not from a list in this packet.

If at execution time there are no non-initiative items on The Hive, the file is created with the empty-state line per Part A 8d.

### Part E — Update the agent's "Step 1: Gather Data" preamble

In `.claude/agents/hive-sync.md`, update the Step 1 introduction. After this packet, the gather phase reads (in addition to the existing five sources):

- The Hive board state via GraphQL (Step 1f, new).

Add a new sub-step **1f** at the end of the existing Step 1:

```markdown
**1f. Query The Hive board (for Step 8 reconciliation).**

Run the GraphQL query described in Step 8a and write the result to `/tmp/hive-items.json`. This is the input to Step 8's non-initiative reconciliation. The query is run once per sync run and reused; do not re-query in Step 8.
```

The Step 1f addition is mechanical and does not duplicate the GraphQL query — Step 8a references the data fetched in Step 1f.

### Part F — Initiative trackers

Update the existing "Hive Sync Rollout (ADR-0014)" entry in `initiatives/active-initiatives.md` (created by Packet 01, last touched by Packet 02) by checking off Packet 03:

```markdown
- [x] Architecture#NN: Track non-initiative board items + Hive-Sync invariant for board coverage (packet 03)
```

The Packet 04, 05, and 06 checkboxes remain unchecked.

## Affected Files

- `.claude/agents/hive-sync.md` — add Step 1f, add Step 8 (Reconcile Non-Initiative Board Items), renumber subsequent steps, append two bullets to Constraints
- `constitution/invariants.md` — append the board-coverage invariant inside the existing "Hive Sync Invariants" section at the next-available number (Part C lookup)
- `initiatives/board-items.md` — **new file**, seeded from the current Hive state
- `initiatives/active-initiatives.md` — check off Packet 03
- `CHANGELOG.md` — append entry referencing the board-items tracking and the board-coverage invariant

## NuGet Dependencies

None. This is a docs/markdown change; no .NET projects touched.

## Boundary Check

- [x] Architecture-only edits. No other repo touched.
- [x] No new code or build artifact.
- [x] No GraphQL **mutations** introduced — query-only access to The Hive. The `secrets.INITIATIVES_SYNC_TOKEN` must have the **`read:project`** scope (classic PAT) or the org-level **`Projects: Read-only`** permission (fine-grained PAT) for the `projectV2` query in Step 8a to succeed; verifying that scope is a Human Prerequisite below, not an assumption made by this packet.
- [x] Invariant 24 preserved — no edits to existing filed packets.
- [x] Invariant 33 preserved — `scope.md` and `review.md` context-loading sections are untouched.

## Acceptance Criteria

- [ ] `.claude/agents/hive-sync.md` contains a Step 1f titled "Query The Hive board (for Step 8 reconciliation)" inside the existing Step 1 (Gather Data).
- [ ] `.claude/agents/hive-sync.md` contains a Step 8 titled "Reconcile Non-Initiative Board Items" with the GraphQL query, categorization, and rendering logic specified in Part A.
- [ ] The lifecycle step that Packet 02 added is renumbered from Step 8 to Step 9. The Commit and Open PR step is renumbered to Step 10. All in-text references inside the agent file are updated to match.
- [ ] The Constraints block contains the two new bullets specified in Part B (read-only with respect to Hive; full rewrite of board-items.md).
- [ ] `constitution/invariants.md` contains the board-coverage invariant inside the existing "Hive Sync Invariants" section. Its numbering is chosen by Part C's lookup procedure (next-available integer at execution time). The **textual content** of the invariant matches the prose in Part C verbatim — the integer prefix may differ from the ADR-0014 authored value (39) without causing a fail.
- [ ] `initiatives/board-items.md` exists. It contains:
  - The header text from Part A 8d (verbatim)
  - The `Last synced:` line with the current date (or the merge date)
  - Either a populated Open table, populated Recently Closed table, or the `_No non-initiative items on The Hive._` empty-state line
- [ ] If at execution time the nightly-security job has produced any open issues, every such issue appears in the Open table of `board-items.md` with the correct repo, category=`security`, label list, and opened date.
- [ ] No issue URL appears in both `filed-packets.json` and `board-items.md`. The two surfaces are disjoint by construction.
- [ ] **Coverage + disjointness verifier passes.** Run the following block locally (with `gh auth status` authenticated for the org) and confirm both checks return empty output:

  ```bash
  # 1. Get all open + recently-closed issue URLs on The Hive (cap at 200 per page; paginate if more)
  gh api graphql -f query='
  { organization(login: "HoneyDrunkStudios") {
      projectV2(number: 4) {
        items(first: 200) {
          nodes { content { ... on Issue { url state } } }
        } } } }' \
    | jq -r '.data.organization.projectV2.items.nodes[].content.url // empty' \
    | sort -u > /tmp/hive-urls.txt

  # 2. Get all packet-sourced URLs
  jq -r 'to_entries[].value' generated/issue-packets/filed-packets.json \
    | sort -u > /tmp/packet-urls.txt

  # 3. Get all URLs in board-items.md (Open + Recently Closed tables)
  grep -oE 'https://github.com/[^)]+' initiatives/board-items.md \
    | sort -u > /tmp/board-urls.txt

  # 4. Disjointness — must be empty (no URL in both packet-urls AND board-urls)
  comm -12 /tmp/packet-urls.txt /tmp/board-urls.txt

  # 5. Coverage — must be empty (every Hive URL is in either packet-urls or board-urls)
  comm -23 /tmp/hive-urls.txt <(sort -u /tmp/packet-urls.txt /tmp/board-urls.txt)
  ```

  Both `comm` invocations must produce empty output. If step 4 emits any URL, the same issue is tracked twice (bug). If step 5 emits any URL, an issue exists on The Hive that the agent did not capture (gap). The verifier must pass against the PR branch's HEAD before merge.
- [ ] `initiatives/active-initiatives.md` "Hive Sync Rollout (ADR-0014)" entry shows Packet 03's checkbox as checked.
- [ ] Repo-level `CHANGELOG.md` entry appended for this version with a one-line summary referencing the non-initiative tracking addition and the new board-coverage invariant.
- [ ] `README.md` for the `initiatives/` folder, if one exists, is updated to mention `board-items.md` alongside the existing files. (If no folder README exists, this criterion is N/A — do not create one.)

## Human Prerequisites

**Pre-merge (BLOCKING — verify before approving the PR):**

- [ ] **Verify the `INITIATIVES_SYNC_TOKEN` PAT scope.** The Step 8a GraphQL query (`organization.projectV2`) requires either the classic-PAT scope `read:project` or the fine-grained-PAT permission `Projects: Read-only` at the **organization** level. Open GitHub → Settings → Developer settings → Personal access tokens, find the token backing the `INITIATIVES_SYNC_TOKEN` repo secret, and confirm the scope is present. If absent, expand the scope before merging. **Document the verified scope in the PR body** so the merge gate is auditable.
- [ ] **Run the GraphQL query as a dry-run** before the agent commits the PR. From a developer machine where `gh auth status` shows authentication for `HoneyDrunkStudios`, run the exact query from Step 8a and confirm it returns at least one item (or empty results — but no permission error):

  ```bash
  gh api graphql -f query='
  {
    organization(login: "HoneyDrunkStudios") {
      projectV2(number: 4) {
        items(first: 10) {
          nodes {
            content { ... on Issue { number title url state } }
          }
        }
      }
    }
  }' | jq '.data.organization.projectV2.items.nodes | length'
  ```

  If the response is a number (item count) the scope is sufficient. If it is `null` or an error mentions `INSUFFICIENT_SCOPES`, the token must be expanded before merge. The dry-run uses the developer's own `gh auth` not the workflow's secret, but the same scope rules apply — if `read:project` works locally, the workflow's PAT with the same scope will work in CI.

**Post-merge (sanity checks, not blockers):**

- [ ] After merge, observe the **next scheduled Monday/Thursday run** of `hive-sync.yml` to confirm the GraphQL query executes successfully under `INITIATIVES_SYNC_TOKEN` in CI. If the dry-run passed but the CI run fails, the workflow's secret may point at a different PAT than the one verified above — surface this as an `infrastructure/` cleanup follow-up.
- [ ] Confirm that `board-items.md` is regenerated correctly on the second run as well. The first run is the seed (created by this packet's PR); the second run validates that the agent regenerates the file from live GraphQL state without leaving stale content.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

This invariant is the reason `board-items.md` is a separate surface from `filed-packets.json`. Synthesizing fake packet entries for non-initiative items would let `filed-packets.json` map every Hive issue, but it would violate the invariant that packets are authored by the scope agent and represent scoped intentional work.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other.

This packet does not touch `scope.md` or `review.md`. The new file `board-items.md` is the `hive-sync` agent's own surface; it is not part of either the scope or review agent's required-reading list.

## Referenced ADR Decisions

**ADR-0014 D3 (Non-initiative issue tracking):** The agent queries The Hive board via GraphQL, subtracts the set of issues known from `filed-packets.json`, and writes the remainder to `initiatives/board-items.md`. Open items are always listed; closed items appear in "Recently Closed" for 30 days then are removed. The agent does not set or modify Hive fields. No initiative association is assigned. If a non-initiative item is later scoped into an initiative, the scope agent creates packets, and the item naturally moves from `board-items.md` into the initiative tracking files on the next sync.

**ADR-0014 Phase Plan, Phase 3 exit criterion:** "every issue on The Hive appears in either an initiative tracking file or `board-items.md`."

**ADR-0014 Alternative-rejected (separate `ops-sync` agent):** Two agents reading live issue state from the same board on overlapping schedules is a coordination burden for no gain. The sync logic is identical; splitting it means two PRs per sync cycle, two agent definitions, and a seam where initiative vs. non-initiative classification can drift. A single agent with a broader mandate is the chosen path.

**ADR-0014 Alternative-rejected (write back to The Hive):** The agent reads The Hive and writes to Architecture files. The reverse direction is handled by `file-issues` and `hive-field-mirror`. Giving `hive-sync` write access to the board would create bidirectional sync, which is a coordination hazard.

## Dependencies

- Wave 2: [Packet 02 — Add packet lifecycle (`active/` → `completed/`) to `hive-sync`](./02-architecture-packet-lifecycle.md)

Reason: this packet inserts Step 8 ahead of the lifecycle step, requiring the lifecycle step to already exist (so it can be renumbered correctly). It also appends the board-coverage invariant inside the "Hive Sync Invariants" section that Packet 02 created. Running this packet before Packet 02 would force creating the section, a partial Constraints update, and a Step ordering that Packet 02 would have to re-do.

## Labels

`feature`, `tier-2`, `meta`, `docs`, `adr-0014`, `wave-3`

## Agent Handoff

**Objective:** Add the GraphQL Hive board query and the `board-items.md` tracking surface to `hive-sync`, encode the board-coverage invariant inside the existing "Hive Sync Invariants" section at the next-available number, and seed the file from the current Hive state.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (suggested branch name: `chore/adr-0014-hive-sync-phase-3`).

**Context:**
- Goal: Third of six phases in the ADR-0014 rollout. Closes the gap between auto-wired Hive issues and Architecture-repo tracking.
- Feature: ADR-0014 — Hive–Architecture Reconciliation Agent.
- ADRs: ADR-0014.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Packet 02 (this initiative, Wave 2) must merge first.

**Constraints:**
- **Invariant 24** (full text above) — no edits to filed packet bodies.
- **Invariant 33** (full text above) — `scope.md` and `review.md` context-loading sections are not modified.
- **Read-only with respect to The Hive board.** No GraphQL mutations against `projectV2`. The agent never sets fields, changes status, modifies labels, or closes issues from this code path.
- **Full rewrite of `board-items.md` each run.** No append-only history. No hand-edits preserved.
- **Single source of truth for issue→tracking mapping:** `filed-packets.json` (initiative work) XOR `board-items.md` (non-initiative work). No issue URL appears in both.
- **Board-coverage invariant prose is verbatim.** The text in Part C must land exactly as written (substituting the chosen integer for `{N}`), including the explicit board number (`org Project #4`) and the parenthetical list of initiative tracking files.
- **No hardcoded invariant number.** Part C looks up the next-available integer at execution time. Do not write a literal `39.` if the file's current max is something else.

**Key Files:**
- `.claude/agents/hive-sync.md` — insert Step 1f, insert Step 8, renumber Steps 9-10, append Constraints bullets.
- `constitution/invariants.md` — append the board-coverage invariant inside the existing "Hive Sync Invariants" section at the next-available number (Part C lookup).
- `initiatives/board-items.md` — create with seeded content from live GraphQL.
- `initiatives/active-initiatives.md` — check off Packet 03.

**Contracts:**
- The GraphQL query shape (Part A 8a) is the contract between the agent and The Hive's `projectV2` resource. If GitHub changes the schema, this query is the place that breaks; the failure surfaces as a sync run failure with a GraphQL error.
- `board-items.md`'s table columns are the contract between the agent and human readers. Adding columns is forward-compatible (rewriters fill them); removing columns is breaking.
