# HoneyDrunk.Notify — Invariants

1. **Notifications are channel-agnostic at the contract level.** Application code sends a notification, not an email or SMS.
2. **Delivery is async via queues.** Direct synchronous send is not supported in production.
3. **Provider failures do not crash the worker.** Failed notifications are retried with backoff.
