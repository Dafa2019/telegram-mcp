# Automation Suite

These files are a version-controlled blueprint for Tembo automations.
Create the real automations in the Tembo dashboard using the prompts in `prompts/`.

## Recommended enablement order
1. `pr-review`
2. `daily-slack-changelog`
3. `security-scan`
4. `auto-fix-ci`
5. `sentry-auto-fix`

## Why this order
- It starts with review-only and reporting workflows.
- It delays code-changing automations until the rule file and team trust are in place.
