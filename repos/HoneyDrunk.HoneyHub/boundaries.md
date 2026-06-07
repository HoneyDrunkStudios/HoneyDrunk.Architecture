# HoneyDrunk.HoneyHub - Boundaries

## What HoneyHub Owns

- Session UI for starting, watching, replying to, stopping, and following up on agent runs.
- Transcript display and run status.
- State-only notification surfacing.
- Policy hints and usage analytics.
- Artifact links for branches, commits, PRs, packets, ADR/PDR drafts, reports, and log bundles.
- The local runner bridge boundary: process launch and lifecycle, official CLI driving, stream parsing, pairing, workspace-root allowlist, backend allowlist, and artifact detection.
- Local-first `DispatchSession` and `UsageSignal` storage.
- The app-tier routing engine once Phase 3 begins.

## What HoneyHub Does Not Own

- A code editor or terminal. Coding stays in the user's IDE and terminal; HoneyHub is the cockpit.
- Authoritative Architecture, catalog, ADR, PDR, or code state. Durable writes land through reviewable branches, PRs, packets, or drafts.
- Vendor subscription auth. HoneyHub never holds, stores, or proxies subscription credentials.
- The canonical routing-policy contract. `HoneyDrunk.AI` owns `IRoutingPolicy`; HoneyHub consumes it.
- The Grid cost-rate table. HoneyHub reads the ADR-0052 / ADR-0016 rate surface for derived USD values.
- Cloud hosted execution at v1. Any future cloud execution is BYO API key only and gated by separate validation.

## Boundary Rules

1. HoneyHub controls sessions; agent CLIs do the agent work.
2. HoneyHub records artifacts; PRs remain the write boundary.
3. HoneyHub reads local usage; exact, derived, and estimated values stay visibly distinct.
4. HoneyHub pairs explicitly with local bridges; unpaired clients cannot control local processes.
5. HoneyHub stores local data by default; sync is explicit and user-controlled.
