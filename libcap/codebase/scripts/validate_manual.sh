#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "validate_manual.sh requires root or CAP_SETFCAP" >&2
  exit 1
fi

make -C "$ROOT_DIR" build/manual_toctou_poc
"$ROOT_DIR/build/manual_toctou_poc"
