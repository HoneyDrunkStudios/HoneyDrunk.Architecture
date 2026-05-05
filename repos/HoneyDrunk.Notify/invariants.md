# HoneyDrunk.Notify — Invariants

1. **Notifications are channel-agnostic at the contract level.** Application code sends a notification, not an email or SMS.
2. **Delivery is async via queues/intake.** Direct synchronous provider calls are not the production path.
3. **Provider failures do not crash the worker/function.** Failed notifications are retried or surfaced as delivery outcomes.
4. **Notify does not evaluate recipient preference or cadence policy.** Those decisions belong in Communications.
5. **Notify validates delivery shape, not business intent.** Missing/invalid delivery fields are Notify concerns; send/suppress/workflow decisions are Communications concerns.
