#!/usr/bin/env bash
# Optica2 for physical devices / LAN: bind all interfaces (not localhost-only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPTICA2_DIR="${OPTICA2_DIR:-}"
if [[ -z "$OPTICA2_DIR" && -f "$ROOT/tool/optica2_dir" ]]; then
  OPTICA2_DIR="$(head -1 "$ROOT/tool/optica2_dir" | tr -d '\r')"
fi
if [[ -z "$OPTICA2_DIR" ]]; then
  OPTICA2_DIR="$(cd "$ROOT/../../Ecommerce Websites/optica2" 2>/dev/null && pwd || true)"
fi
if [[ ! -f "${OPTICA2_DIR}/artisan" ]]; then
  echo "Optica2 not found. Set OPTICA2_DIR or create tool/optica2_dir" >&2
  exit 1
fi
cd "$OPTICA2_DIR"
echo "Serving Optica2 on http://0.0.0.0:8000 (LAN + emulator)"
exec php artisan serve --host=0.0.0.0 --port=8000
