#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R "__.*__" "$ROOT"; then
  echo "[WARN] unresolved placeholders found"
  exit 1
fi
echo "[OK] no unresolved placeholders found"
