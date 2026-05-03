# Hive Sync OpenClaw Runtime

`hive-sync` is the OpenClaw/Honeyclaw scheduled/manual agent job that reconciles the HoneyDrunk.Architecture repo with The Hive.

## Runtime Contract

- **Schedule:** Monday/Thursday at 06:00 UTC (`0 6 * * 1,4`), matching the former cadence unless Oleg changes it in OpenClaw cron.
- **Target:** isolated OpenClaw `agentTurn`, not GitHub Actions.
- **Working repo:** `HoneyDrunkStudios/HoneyDrunk.Architecture`.
- **Prompt source:** `.claude/agents/hive-sync.md`.
- **Allowed tools/capabilities:** read/write/edit files, run `gh`, run GraphQL via `gh api graphql`, create or update the reconciliation PR.
- **Output:** concise executive summary to Oleg with files changed, PR URL, and any blockers.
- **Safety:** read-only with respect to The Hive board except for PR creation in Architecture; no GraphQL mutations to board fields.

## Runtime Boundary

GitHub remains the source of truth and PR surface. OpenClaw owns scheduling, reasoning, branch creation, commits, and PR creation/update. If a GitHub Actions workflow is ever reintroduced, it should be a dumb health or validation trigger, not an Anthropic/Claude API caller and not the reasoning brain.

## Auth Expectations

The OpenClaw host must have an authenticated `gh` context with access to HoneyDrunkStudios repos and org Project #4. Board reads use `gh api graphql`; issue and PR operations use `gh issue`, `gh pr`, and normal git remotes.
