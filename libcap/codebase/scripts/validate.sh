#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

make -C "$ROOT_DIR" clean all
"$ROOT_DIR/scripts/validate_manual.sh"
"$ROOT_DIR/scripts/validate_setcap_tool.sh"
