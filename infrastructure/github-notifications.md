# GitHub Actions Failure Notifications

**Purpose:** Configure GitHub profile notifications so failed Grid workflows reach the operator in real time.  
**Audience:** Solo operator today; future on-call humans later.  
**Scope:** Per-GitHub-account setting. This is not an org-level or repo-level switch.  
**Last verified:** 2026-05-25.

## Why this matters

ADR-0012 uses two complementary CI/CD visibility mechanisms. D7 is the real-time path: GitHub sends an email when a workflow run fails. D6 is the aggregate path: the `HoneyDrunk.Actions` `🕸️ Grid Health` issue is refreshed daily by the grid-health aggregator. Invariant 40 requires both mechanisms because they cover different failure windows.

The mid-day failure case is the reason D7 exists. If a workflow fails at 11:00, profile notifications should send email at 11:00 when the run completes. Without that setting, the failure may not become visible until the next grid-health pass at 03:30 UTC the next morning.

## Step-by-step portal walkthrough

1. Open <https://github.com/settings/notifications> while signed in as the operator account.
   - This is a profile setting, so each future operator must configure it on their own GitHub account.
2. Scroll to **Actions**.
   - This section controls notifications for workflow runs on repositories you watch or workflows you trigger.
3. Under **Notifications for workflow runs on repositories you're watching, or for workflows you've triggered**, confirm **Email** is enabled.
   - Email is the load-bearing real-time path for ADR-0012 D7; web/mobile notifications are useful but not enough by themselves.
4. In the Actions notification option, select **Only notify for failed workflows**.
   - Failed-only keeps signal high. "All workflows" is too noisy for a growing Grid; "none" defeats D7.
5. Under **Custom routing**, if configured, confirm workflow notifications route to the operator's primary inbox.
   - A notification sent to an ignored mailbox is operationally equivalent to no notification.
6. Confirm the operator is watching every active `HoneyDrunkStudios/*` repository whose workflows should generate failure mail.
   - GitHub sends these workflow-run notifications for watched repositories and workflows the account triggered. Repository watch state is the per-repo prerequisite for passive failure visibility.

Screenshots are intentionally optional. The labels above are sufficient to complete the setup even when GitHub's visual layout shifts.

## Verification

1. Trigger a deliberate workflow failure in a sandbox branch or sandbox repository. Prefer a harmless fixture such as a temporary YAML syntax error in a non-production workflow.
2. Wait for the workflow run to complete as failed.
3. Within about one minute, confirm the operator inbox receives a GitHub Actions failure email. The subject should follow GitHub's workflow notification shape, for example: `[HoneyDrunkStudios/<repo>] Run failed: ...`.
4. If no email arrives within five minutes:
   - Re-check that the repository is watched by the operator account.
   - Re-check that **Email** is enabled under **Actions** notifications.
   - Re-check that **Only notify for failed workflows** is selected.
   - Re-check **Custom routing** if the account routes GitHub notifications to more than one address.

Do not verify by breaking a production deployment path. A sandbox failure is enough to prove the notification route.

## Multi-operator note

HoneyDrunk Studios is one operator today. If operations grow beyond one human, either each operator repeats this profile walkthrough, or ADR-0012 D6 grows a team-channel notification integration such as Slack or Discord from the grid-health aggregator. That design is deliberately deferred; this runbook only documents the mandatory per-account mechanism ADR-0012 already chose.

## References

- [ADR-0012 D7 — GitHub profile notifications are the real-time notification mechanism](../adrs/ADR-0012-grid-cicd-control-plane.md#d7---github-profile-notifications-are-the-real-time-notification-mechanism)
- [ADR-0012 D6 — Grid Health aggregator](../adrs/ADR-0012-grid-cicd-control-plane.md#d6---grid-health-aggregator-is-the-pipeline-observability-surface)
- [Invariant 40 — Grid pipeline health is centrally visible](../constitution/invariants.md#grid-cicd-invariants)
- Future cross-link: the `🕸️ Grid Health` issue in `HoneyDrunk.Actions` once packet 04 creates it.
