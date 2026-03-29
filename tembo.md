# Project Context - Dafa2019/telegram-mcp

This repository is managed with Tembo.
Follow this file as the primary source of repo-level instructions.

## Mission
- Maintain production stability first.
- Prefer small, reviewable pull requests.
- Preserve existing business logic unless the task explicitly requires changing it.
- Prefer traceable changes with tests, docs, and rollback notes.

## Tech stack
- **Runtime**: Python 3.10+
- **Package manager**: pip (dependencies in `requirements.txt` and `pyproject.toml`)
- **MCP server**: FastMCP (`mcp[cli]>=1.8.0`) — 123+ Telegram tools
- **Telegram client**: Telethon (`telethon>=1.39.0`)
- **Web dashboard**: FastAPI + Uvicorn (REST API) + Vue.js 3 (static frontend in `/static`)
- **Legacy dashboard**: Flask (`flask>=3.0.0`)
- **Async**: asyncio + nest-asyncio + aiohttp
- **QR login**: qrcode + Pillow + Playwright (browser-based QR)
- **Config**: python-dotenv (`.env` file)
- **Build system**: setuptools (pyproject.toml)
- **Container**: Docker + docker-compose

## Commands
- Install: `pip install -r requirements.txt`
- Run MCP server: `python main.py`
- Run Web Dashboard: `python dashboard.py` (serves on `http://localhost:8080`)
- Run tests: `python test_comprehensive.py` / `python test_new_features.py` / `python test_tools.py`
- Setup (interactive): `bash setup.sh`
- Docker: `docker-compose up -d`

There is no dedicated `lint`, `typecheck`, or `format` command configured. The project uses `black` (line-length 99, target py311) as declared in `pyproject.toml`.

If a command is missing, inspect `pyproject.toml`, `requirements.txt`, or project docs before inventing a replacement.

## Repository structure
- `main.py` — MCP server entry point (123+ Telegram tools via FastMCP)
- `dashboard.py` — FastAPI web dashboard backend (REST API + static file serving)
- `web_login.py` — Web-based login flow (QR code + phone number)
- `qr_login.py` — CLI QR code login
- `qr_web_login.py` — Browser-based QR login via Playwright (Pyro)
- `pyro_qr_login.py` — Pyrogram-based QR login
- `login.py` — Legacy CLI login
- `session_manager.py` — Multi-account session management
- `account_manager.py` — Account lifecycle management
- `account_tools.py` — Account-related MCP tools
- `batch_operations.py` — Batch message sending operations
- `scheduler.py` — Scheduled task management (cron + one-time)
- `template_manager.py` — Message template management with variable substitution
- `proxy_manager.py` — Proxy configuration (global + per-account)
- `health_monitor.py` — Account health monitoring and risk detection
- `stats_tracker.py` — Usage statistics tracking
- `log_manager.py` — Logging management
- `/static` — Vue.js 3 frontend (dashboard HTML/JS/CSS)
- `/accounts` — Account session storage (do NOT commit real sessions)
- `/docs` — Documentation
- `/patches` — Patch files (if any)
- `config.example.json` — Example configuration
- `Dockerfile` + `docker-compose.yml` — Container configuration
- `setup.sh` — Interactive setup script
- `/.github` — CI workflows and automation scripts
- `/.tembo` — Tembo rollout documentation and automation blueprints

## Workflow rules
- Base branch: `main`
- Keep changes scoped to the requested task.
- Do not change `requirements.txt` unless the task requires adding/removing/updating dependencies.
- If modifying MCP tool definitions in `main.py`, ensure tool annotations are preserved.
- If touching authentication, session management, or Telegram API calls, add explicit risk notes in the PR description.

## Code style
- Follow PEP 8 conventions.
- Use `black` for formatting (line-length 99, target py311).
- Prefer explicit typing and avoid `Any` unless justified.
- Prefer existing architectural patterns over stylistic rewrites.
- Preserve public API contracts (MCP tool signatures) unless the task explicitly allows breaking changes.
- Keep file naming and import ordering consistent with surrounding code.

## Testing expectations
- Test files: `test_comprehensive.py`, `test_new_features.py`, `test_tools.py`, `test_edge_cases.py`, `test_web.py`
- Run individual test files with `python <test_file>.py`.
- Verification: `python verify_tools.py` to verify tool registration.
- If tests cannot run locally (e.g. missing Telegram session), explain why and document the exact blocker.

## Documentation expectations
- Update docs when behavior, config, or operational workflows change.
- Include example commands when adding new setup steps.
- Keep `docs/` up to date when modifying architecture or data flows.

## IMPORTANT
- Prefer review-only behavior for automations unless explicitly configured for code changes.
- For PR review automations, do not auto-approve if there is uncertainty.
- For CI auto-fix, stop after bounded retries and leave a clear summary.

## WARNING - protected areas
- Do not modify secrets, credentials, or token values in any file.
- Do not write real API keys, Telegram sessions, or tokens into code, rule files, prompts, or docs.
- Do not change deployment or infra files unless the task explicitly targets them.
- Do not rename top-level modules without explicit task scope.
- Do not modify `/accounts/` directory contents — these contain live session data.
- Do not modify `Dockerfile` or `docker-compose.yml` without explicit approval.
- Do not commit `.env` files or session files.

## Environment variables
Required env vars (see `config.example.json` and `main.py`):
- `TELEGRAM_API_ID` — Telegram API ID (default: 2040)
- `TELEGRAM_API_HASH` — Telegram API hash
- `SESSION_FILE` — Path to session file (default: `.telegram_session`)
- `TEMBO_API_KEY` — Tembo API key (GitHub Secret, not in repo)
- `SLACK_WEBHOOK_OPS_ALERTS` — Slack webhook for ops notifications (GitHub Secret)

## Pull request expectations
Every PR should include:
1. What changed
2. Why it changed
3. Risk / impact
4. Test evidence
5. Rollback plan

## Agent behavior
- Ask for human review whenever the task may change production behavior significantly.
- Prefer one focused PR instead of one broad PR.
- If the task is ambiguous, choose the safest interpretation and document assumptions.
