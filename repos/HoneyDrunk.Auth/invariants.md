# HoneyDrunk.Auth — Invariants

1. **Auth validates tokens, never issues them.**
2. **Signing keys come from Vault only.** Never hardcoded or from config files.
3. **Startup validation fails fast.** Missing Vault or invalid signing key configuration stops the application.
4. **Policy evaluation is pure.** `AuthorizationPolicyEvaluator` has no side effects.
