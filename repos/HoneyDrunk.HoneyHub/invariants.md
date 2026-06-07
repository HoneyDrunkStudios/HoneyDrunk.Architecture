# HoneyDrunk.HoneyHub - Local Invariants

HoneyHub adds no `constitution/invariants.md` entry at standup. These are Node-local operating rules inherited from PDR-0011 and ADR-0090 through ADR-0092.

1. The bridge drives each vendor's official CLI under the user's own local session; HoneyHub never holds, stores, or proxies subscription auth.
2. Cloud or hosted execution is BYO API key only, never a subscription token.
3. Artifacts are the write boundary: no direct mutation of authoritative state outside a reviewable git branch or PR.
4. Capability flags are honest. The bridge never fakes live interaction a backend lacks.
5. Notifications are state-only: status, backend, repo, and link only; never prompt text, code, secrets, stack traces, or full paths.
6. Local-first data is the default. Session or workspace sync is explicit opt-in, and there is no central transcript store at v1.
7. Usage fidelity is always tagged `exact`, `derived`, or `estimated`; the UI never renders an estimate as an exact figure.
8. `HoneyDrunk.AI` owns the canonical `IRoutingPolicy` contract; HoneyHub consumes it and does not fork a parallel routing abstraction.
9. Routing means capability/cost fit plus the user's own subscription headroom. It never means cap-dodging, rate-limit evasion, account multiplexing, or credential rotation.
10. HoneyHub is not an editor and not a terminal.
