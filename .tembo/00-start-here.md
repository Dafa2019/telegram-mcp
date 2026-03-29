# Start Here

Use this package as a Tembo rollout layer for an existing engineering repository.

## Order of operations

1. Fill placeholders.
2. Review `tembo.md` and adapt commands / paths to the actual repo.
3. Connect GitHub first.
4. Connect Slack and optionally Linear / Sentry.
5. Add MCP servers only when there is a concrete use case.
6. Enable review-only workflows first.
7. Enable code-changing workflows later.

## Initial safe rollout

- Week 1: `pr-review`, `daily-slack-changelog`
- Week 2: `security-scan`
- Week 3: `auto-fix-ci` in low-risk repos only
- Week 4+: `sentry-auto-fix` for well-tested production repos
