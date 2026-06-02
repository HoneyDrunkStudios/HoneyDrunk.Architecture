# ADR-0043 Opportunistic Scout Source

You are running as the ADR-0086 `backlog-opportunistic-scout` scheduled job for `HoneyDrunk.Architecture`.

Objective: run a monthly product-strategy Scout pass, write the report, and create proposed packets only when an opportunity clears the bar.

## Monthly Guard

This job is scheduled weekly for Task Scheduler portability. If `generated/scout-reports/` already contains a report for the current calendar month, write no new files and exit cleanly unless the operator explicitly invoked the job manually.

## Load First

Read:

1. `adrs/ADR-0043-continuous-backlog-generation-strategy.md`
2. `.claude/agents/product-strategist.md`
3. `.claude/agents/scope.md`
4. `copilot/issue-authoring-rules.md`
5. `constitution/charter.md`
6. `constitution/manifesto.md`
7. `catalogs/nodes.json`
8. `catalogs/relationships.json`
9. `pdrs/`
10. `adrs/`
11. `initiatives/active-initiatives.md`
12. `initiatives/roadmap.md`
13. Existing packets under `generated/issue-packets/{proposed,active,completed}/`

Use web search for current market signal when available. Cite web sources in the report, but do not quote long passages.

## Branch And PR

Create or reuse branch `chore/backlog-opportunistic-scout-{YYYY-MM-DD}`. Open or update one PR against `main` if files change. PR body must include:

- `Authorship: agent-codex`
- `Out-of-band reason: ADR-0043 backlog-opportunistic-scout scheduled runner job`
- Recommendation, packet count, and any PDR handoff needed

## Work

1. Run Scout mode from `product-strategist`.
2. Write `generated/scout-reports/{YYYY-MM-DD}.md`.
3. If the recommendation is "build nothing" or "stay the course", create no packets.
4. If an opportunity needs product-level decision-making, create a proposed Architecture packet for `pdr-composer` to author or amend the PDR. Do not write the PDR yourself.
5. If an opportunity is a small in-scope improvement, create a proposed packet directly.
6. Proposed packets:
   - Land in `generated/issue-packets/proposed/{YYYY-MM-DD}-{repo-short}-{description}.md`.
   - Include `source: opportunistic` and `generator: product-strategist`.
   - Cite the Scout report path in Context.
7. Dedupe before writing.

## Constraints

- Do not move packets to `active/`.
- Do not create GitHub issues or mutate The Hive board.
- Never propose more than four opportunities.
- Never create a packet without kill criteria or opportunity-cost context.
