#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cat >"$ROOT_DIR/invariant_scores.json" <<'EOF'
{
  "invariant_scores": {}
}
EOF
