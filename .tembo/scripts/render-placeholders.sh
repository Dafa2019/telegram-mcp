#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 8 ]; then
  echo "Usage: $0 ORG_NAME REPO_NAME DEFAULT_BRANCH ENGINEERING_CHANNEL SECURITY_CHANNEL SENTRY_PROJECT LINEAR_TEAM TIMEZONE"
  exit 1
fi

ORG_NAME="$1"
REPO_NAME="$2"
DEFAULT_BRANCH="$3"
ENGINEERING_CHANNEL="$4"
SECURITY_CHANNEL="$5"
SENTRY_PROJECT="$6"
LINEAR_TEAM="$7"
TIMEZONE="$8"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

find "$ROOT" -type f \
  ! -name "*.zip" \
  ! -path "*/.git/*" \
  -print0 | while IFS= read -r -d '' file; do
  perl -0pi -e "s/Dafa2019/$ORG_NAME/g; s/telegram-mcp/$REPO_NAME/g; s/main/$DEFAULT_BRANCH/g; s/#engineering/$ENGINEERING_CHANNEL/g; s/#security-alerts/$SECURITY_CHANNEL/g; s/telegram-mcp/$SENTRY_PROJECT/g; s/Crown/$LINEAR_TEAM/g; s/Asia/Singapore/$TIMEZONE/g;" "$file"
done

echo "[OK] placeholders rendered"
