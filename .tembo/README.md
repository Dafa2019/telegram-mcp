# Tembo Starter Repo

A practical Tembo rollout kit for an engineering repo.

This package is designed for teams that want to:
- add a high-quality `tembo.md` rule file
- document model routing and guardrails
- keep MCP configuration in version control
- define automation prompts before enabling them in Tembo
- start with low-risk review workflows, then expand to auto-fix

## What this repo contains

- `tembo.md` - primary Tembo rule file for the target repo
- `docs/` - setup checklist, routing policy, rollback plan, agent handoff
- `automation-suite/` - versioned automation blueprints and prompt drafts
- `examples/` - MCP and Nix examples
- `scripts/` - helper scripts for placeholder replacement and validation
- `.env.example` - environment variable template for MCP and integrations

## Important note

Tembo automations are configured in the Tembo dashboard. The YAML files in this repo are **versioned blueprints**, not an official import contract. Use them as the source of truth for your team, then create or update the corresponding automations in the Tembo UI.

## Fast path

1. Unzip this package.
2. Replace placeholders with `scripts/render-placeholders.sh`.
3. Copy `tembo.md` into the actual code repository root.
4. Review `docs/01-dashboard-setup-checklist.md`.
5. Create the automations in Tembo using the prompts under `automation-suite/prompts/`.
6. Start with `pr-review` and `daily-slack-changelog` only.
7. Enable `security-scan` next.
8. Enable `auto-fix-ci` or `sentry-auto-fix` only after the first two layers are stable.

## Placeholder variables

- `Dafa2019`
- `telegram-mcp`
- `main`
- `#engineering`
- `#security-alerts`
- `telegram-mcp`
- `Crown`
- `Asia/Singapore`

## Suggested initial agent policy

- Complex refactors / security work: Claude Code + `claude-opus-4-6`
- PR review: Codex + `gpt-5.4`
- Low-cost summary / changelog work: Opencode + `gpt-5.4-mini`

## Up-to-date facts verified against Tembo docs

- Tembo supports multiple coding agents and recommends `tembo.md` as the primary rule file. Tembo only uses the first matching rule file in its supported list.
- Current docs show Codex defaulting to `gpt-5.2`, even though `gpt-5.3-codex` and `gpt-5.4` are supported. This starter kit therefore avoids claiming that `gpt-5.3-codex` is the global Codex default.
- Automations run from natural-language instructions in Tembo and can be triggered by schedules or events.

