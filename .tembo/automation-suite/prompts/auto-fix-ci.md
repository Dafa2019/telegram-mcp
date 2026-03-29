When a GitHub workflow run fails for repository Dafa2019/telegram-mcp:

1. Inspect only the failing workflow, logs, and directly related files.
2. Attempt a minimal fix for deterministic issues such as lint, formatting, import errors, or brittle tests.
3. Do not change business logic unless the logs clearly require it.
4. Stop after 2 attempts.
5. If the cause is ambiguous, leave a summary and do not open a broad PR.
6. Exclude bot-authored loops.
